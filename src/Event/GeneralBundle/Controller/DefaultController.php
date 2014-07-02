<?php

namespace Event\GeneralBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\Controller;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\Session\Session;

# Entities
use Event\GeneralBundle\Entity\InternalEvent;
use Event\GeneralBundle\Entity\InternalProvider;
use Event\GeneralBundle\Entity\Place;
use Event\GeneralBundle\Entity\Artist;
use Event\GeneralBundle\Entity\User;
use Event\GeneralBundle\Entity\UserAudio;
use Event\GeneralBundle\Entity\Sync;
use Event\GeneralBundle\Entity\UserLike;

# Forms
use Event\GeneralBundle\Form\ProviderEventType; 
use Event\GeneralBundle\Form\InternalEventType; 
use Event\GeneralBundle\Form\PlaceType; 
use Event\GeneralBundle\Form\ArtistType; 

# Services
use Event\GeneralBundle\VkApi;
use Event\GeneralBundle\MobileDetect;

class DefaultController extends Controller {

    private function getPopularTags() {
        $tags = array( 11 => 'rock', 10 => 'russian rock', 46 => 'jazz', 39 => 'blues', 78 => 'pop', 6 => 'alternative', 28 => 'electronic', 3 => 'hip-hop', 34 => 'metal', 42 => 'indie', 20 => 'instrumental', 1 => 'rap', 15 => 'punk', 43 => 'british', 4 => 'russian rap', 26 => 'hardcore', 66 => 'chanson', 33 => 'heavy metal', 120 => 'classical', 57 => 'folk', 129 => 'experimental', 124 => '90s', 105 => 'punk rock', 24 => 'metalcore');
        
        return $tags;
    }

    private function getMonthIntervals() {
        $month_name = array(
            1 => 'Январь', 2 => 'Февраль', 3 => 'Март', 4 => 'Апрель', 5 => 'Май', 6 => 'Июнь', 7 => 'Июль', 8 => 'Август', 9 => 'Сентябрь', 10 => 'Октябрь', 11 => 'Ноябрь', 12 => 'Декабрь'
        );

        $dt = new \DateTime;
        $month_intervals = array();
        for ($i = 0; $i < 5; $i++) {
            $m = $dt->add(new \DateInterval('P1M'));
            $month_intervals[ $dt->format('n') ] = $month_name[ $dt->format('n') ]; 
        }

        return $month_intervals;
    }

    private function prepareTimeInterval($interval) {
        $start = new \DateTime;
        $start->setTime(0, 0, 0);
        $end = clone $start;
        $end->setTime(23, 59, 59);

        if ($interval == '14d') {
            $end = $end->add(new \DateInterval('P14D'));
        } elseif ($interval == '31d') {
            $end = $end->add(new \DateInterval('P31D'));
        } elseif ($interval == '90d') {
            $end = $end->add(new \DateInterval('P90D'));
        } elseif (preg_match("/^m(\d+)/", $interval, $matches)) {

            $month_num = $matches[1];
            $start = new \DateTime(date('Y').'-'.$month_num.'-01');
            $end = clone $start;
            $end->add(new \DateInterval('P1M'))->sub(new \DateInterval('P1D'));

        } elseif ($interval == 'weekend') {

            $start = new \DateTime('next Saturday');
            $start->setTime(0, 0, 0);
            $end = clone $start;
            $end = $end->add(new \DateInterval('P1D'));
            $end->setTime(23, 59, 59);

        } else {
            $end = $end->add(new \DateInterval('P12M'));
        }

        return array('start' => $start, 'end' => $end);
    }


    private function getUserLikes( $params = array() ) {
        # Date Interval
        $em = $this->getDoctrine()->getManager();
        $likes = $em->createQuery("select p from EventGeneralBundle:UserLike p where p.start >= :start and p.start <= :end and p.userId = :user_id")
            ->setParameter('start', $params['start'])  
            ->setParameter('end', $params['end'])  
            ->setParameter('user_id', $params['user_id'])  
            ->getResult();

        $ret = array();
        foreach ($likes as $l) {
            $ret[ $l->getIndexId() ] = $l;
        }

        return $ret;
    }

    private function serialIndexEvents ($events) {
        $ret_events = array();
        foreach ($events as $e) {
            array_push($ret_events, array(
                'id' => $e->getId(),
                'internal_id' => $e->getInternalId(),
                'name' => $e->shortName(120),
                'start_short' => $e->shortStartHuman(),
                'start_full' => $e->fullStartHuman(),
                'tags_short' => $e->getTagsNamesList(0, 10),
                'tags_full' => $e->getTagsNamesList(0, 25),
                'catalog_rate' => $e->getCatalogRate(),
                'link' => $this->generateUrl('event', array('year' => $e->getYear(), 'month' => $e->getMonth(), 'event_id' => $e->getUrlId())),
                'weight' => $e->getWeight(),
            ));
        }

        return $ret_events;
    }

    private function getActualInternalIndexByIds( $ids = array(), $params = array() ) {
        $index = array();

        while ( $part = array_splice($ids, 0, 100) ) {
            $ids_str = join(',', $part);

            $em = $this->getDoctrine()->getManager();

            $part_events = array();
            if ( isset($params['start']) && isset($params['end']) ) {
                $part_events = $em->createQuery("select p from EventGeneralBundle:ActualInternalIndex p where p.start >= :start and p.start <= :end and p.id in ($ids_str) order by p.start")
                    ->setParameter('start', $params['start'])  
                    ->setParameter('end', $params['end'])  
                    ->useResultCache(true, 60) 
                    ->getResult();
            } else {
                $part_events = $em->createQuery("select p from EventGeneralBundle:ActualInternalIndex p where p.id in ($ids_str) order by p.start")
                    ->useResultCache(true, 60) 
                    ->getResult();
            }

            foreach ($part_events as $e) {
                array_push($index, $e);
            }
        }

        # Parse by internal id
        if ( !isset($params['parse']) || $params['parse'] == 0 ) {
            return $index;
        } else {
            $ret = array();
            foreach ($index as $i) {
                $ret[ $i->getId() ] = $i;
            }

            return $ret;
        }

        return $index;
    }

    private function getActualInternalIndex( $params = array() ) {
        $index = array();

        # Date Interval
        if ( isset($params['start']) && isset($params['end']) ) {
            $em = $this->getDoctrine()->getManager();
            $index = $em->createQuery("select p from EventGeneralBundle:ActualInternalIndex p where p.start >= :start and p.start <= :end order by p.start ASC")
                ->setParameter('start', $params['start'])  
                ->setParameter('end', $params['end'])  
                ->useResultCache(true, 60) 
                ->getResult();
        } else {
            # Order
            if ( !isset($params['order']) ) {
                $rep = $this->getDoctrine()
                    ->getRepository('EventGeneralBundle:ActualInternalIndex');

                $index = $rep->findAll();

            } else if ($params['order'] == 'catalog_rate') {
                $em = $this->getDoctrine()->getManager();
                $index = $em->createQuery("select p from EventGeneralBundle:ActualInternalIndex p order by p.catalogRate DESC, p.start ASC")
                    ->setMaxResults($params['limit'])
                    ->setFirstResult($params['offset'])
                    ->useResultCache(true, 60) 
                    ->getResult();
            }
        }
        
        # Parse by internal id
        if ( !isset($params['parse']) ) {
            return $index;
        } else {
            $ret = array();
            foreach ($index as $i) {
                $ret[ $i->getInternalId() ] = $i;
            }

            return $ret;
        }
    }

    private function getSessionTags($session) {
        $tags = $session->get('set_tags');

        $tags_json = array();
        if ($tags) {
            $tags_json = json_decode($tags, 1);
        }

        return $tags_json;
    }

    public function setTagAction(Request $r) {
        $tag = $r->get('tag');

        if (!$tag) {
            $answer = array( 'error' => 'no tag' );
            return new Response(json_encode($answer));
        }

        # Get tags
        $session = $r->getSession();
        $tags = $this->getSessionTags($session);

        $action = 'set';
        if (!isset($tags[$tag])) {
            $tags[$tag] = 1;
        } else {
            $action = 'unset';
            unset($tags[$tag]);
        }

        $tags_str = json_encode($tags, 1);
        $session->set('set_tags', $tags_str);

        $answer = array( 'done' => 1, 'tags' => $tags, 'action' => $action );
        return new Response(json_encode($answer));
    }

    private function fetchUserById($id) {
        $em = $this->getDoctrine()->getManager();
        $users = $em->createQuery("select p from EventGeneralBundle:User p where p.id = :id")
            ->setParameter('id', $id)  
            ->useResultCache(true, 60) 
            ->getResult();

        if (!$users || count($users) == 0) {
            return;
        } else {
            return $users[0];
        }
    }

    private function fetchUser($network, $network_id, $auth, $session) {
        $em = $this->getDoctrine()->getManager();
        $users = $em->createQuery("select p from EventGeneralBundle:User p where p.network = :network and p.networkId = :network_id")
            ->setParameter('network', $network)  
            ->setParameter('network_id', $network_id)  
            ->useResultCache(true, 60) 
            ->getResult();

        if ($users && count($users) > 0) {
            return $users[0];
        } else {
            if ($network == $this->container->getParameter('networks.vkontakte.id')) {
                $user = $this->registerVkUser($network_id, $auth);
                $session->getFlashBag()->set('first_time', '1');
                return $user;
            }
        }

        return;
    }

    private function checkSync($user_id, $session) {
        $em = $this->getDoctrine()->getManager();

        $sync_list = $em->createQuery("select p from EventGeneralBundle:Sync p where p.userId = :user_id")
            ->setParameter('user_id', $user_id)  
            ->getResult();

        $sync = array();

        if ($sync_list && isset($sync_list[0])) {
            $sync = $sync_list[0];

            if ($sync->getStatus() == 1 && !$sync->isLastSyncActual()) {
                $sync->setAuthInfo( json_encode( array( 'access_token' => $session->get('access_token') ) ) );
                $sync->setStatus(0);
                $sync->setLastSync();

                $em->persist($sync);
                $em->flush();
            }

        } else {
            $sync = new Sync;
            $sync->setUserId( $user_id );
            $sync->setNetwork( $session->get('network') );
            $sync->setNetworkId( $session->get('network_id') );
            $sync->setAuthInfo( json_encode( array( 'access_token' => $session->get('access_token') ) ) );
            $sync->setStatus(0);
            $sync->setLastSync();

            $em->persist($sync);
            $em->flush();
        }

        return $sync;
    }

/* 
==============================================================================
                        LOGIN, LOGOUT & REGISTRATION 
==============================================================================
*/

    private function registerVkUser($network_id, $auth) {
        $api = $this->get('vk_api');
        $u = $api->getUserInfo($network_id, $auth->access_token);

        if (!$u) {
            throw new \Exception('VK API ERROR');
        }
        
        # Register new user
        $name = $u->first_name.' '.$u->last_name;
        $email = isset($auth->email) ? $auth->email : '';

        $user = new User;
        $user->setName($name);
        $user->setEmail($email);
        $user->setNetwork($this->container->getParameter('networks.vkontakte.id'));
        $user->setNetworkId($network_id);
        $user->setAdditional(json_encode($u));
        $user->setAuthInfo(json_encode($auth));
        $user->setSubscribeSecret(md5( time() . 'subscribe' . $network_id . $name . json_encode($auth) ));

        if ($email) {
            $user->setSubscribe(1);
        } else {
            $user->setSubscribe(0);
        }

        $em = $this->getDoctrine()->getManager();
        $em->persist($user);
        $em->flush();

        return $user;
    }

    public function loginVkAction(Request $r) {
        $code = $r->get('code');

        $network    = $this->container->getParameter('networks.vkontakte.id');
        $app_id     = $this->container->getParameter('networks.vkontakte.app_id');
        $server_key = $this->container->getParameter('networks.vkontakte.server_key');
        $redirect   = $this->container->getParameter('networks.vkontakte.redirect');

        if( $curl = curl_init() ) {
            $url = 'https://oauth.vk.com/access_token?client_id='.
                $app_id
                .'&client_secret='.
                $server_key
                .'&code='.
                $code
                .'&redirect_uri='.
                $redirect;

            curl_setopt($curl, CURLOPT_URL, $url);
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            $out = curl_exec($curl);

            $http_code = curl_getinfo($curl, CURLINFO_HTTP_CODE);

            $session = $r->getSession();

            if($http_code != 200) {
                # TODO: Auth Error handler!
                throw new \Exception('AUTH ERROR');
            } else {
                # Check user and register
                $auth_info = json_decode($out);

                $user = $this->fetchUser($network, $auth_info->user_id, $auth_info, $session);

                if (!$user) {
                    throw new \Exception('USER ERROR');
                }
            }

            curl_close($curl);

            $session->set('user_id', $user->getId());
            $session->set('network', $network);
            $session->set('network_id', $user->getNetworkId());
            $session->set('access_token', $auth_info->access_token);
        }

        return $this->redirect($this->generateUrl('index'));
    }

    public function logoutAction(Request $r) {
        // General info
        $session = $r->getSession();
        $session->clear();
        return $this->redirect($this->generateUrl('index'));
    }

/* 
==============================================================================
                                INDEX PAGE 
==============================================================================
*/

    public function indexAction(Request $r) {
        // General info
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $user = array();
        if ($user_id) {
            $user = $this->fetchUserById($user_id);
        }

        // Tags
        $tags = $this->getSessionTags($session);

        // Check user status (looged or not)
        $sync    = array();
        $events  = array(); 
        $grid    = array();
        $my_tags = array();
        $likes   = array();
        $ecount  = 0;

        if ($user_id) {
            // Check sync status 
            $sync = $this->checkSync($user_id, $session);

            $my_tags = array_slice($user->getTagsListFull('sort'), 0, 50);

            $period = $this->prepareTimeInterval('all'); 
            $likes = $this->getUserLikes(array(
                'user_id' => $user_id, 
                'start'   => $period['start'], 
                'end'     => $period['end'] 
            ));

        } else {
            // Prepare Grid
            $grid = array( array(6, 3, 3), array(3, 6, 3), array(3, 3, 3, 3) ); 
            foreach ($grid as $row) {
                foreach ($row as $e) {
                    $ecount++; 
                }
            }

            // Non logged
            if (count($tags) > 0) {
                $events = $this->getGeneralEventsByTags($tags, 0, $ecount);
            } else {
                $events = $this->getActualInternalIndex(array('order' => 'catalog_rate', 'limit' => 10, 'offset' => 0));    
            }
        }

        // Detect Mobile
        $mob = $this->get('mobile_detect');
        $template = 'EventGeneralBundle:Default:index.html.twig';
        if ($mob->isMobile()) {
            $template = 'EventGeneralBundle:Default:index.mob.html.twig';
        }

        return $this->render($template, array(
            'top'     => 'index',
            'user_id' => $user_id,
            'user'    => $user,
            'session' => $session,
            'sync'    => $sync,
            'events'  => $events,
            'grid'    => $grid,
            'events_on_page' => $ecount,
            'popular_tags' => $this->getPopularTags(),
            'tags_name_selected' => $tags,
            'my_tags' => $my_tags,
            'my_tags_short' => array_slice($my_tags, 0, 30),
            'likes'   => $likes,
            'month_intervals' => $this->getMonthIntervals(),
        ));
    }

    private function generateGrid($rows_count, $mult = 1) {
        $grid = array(
            array( 1, 1, 1, 1 ),
            array( 2, 1, 1),
            array( 1, 2, 1),
            array( 1, 1, 2),
        );

        $ret = array();
       
        if ($rows_count > count($grid)) {
            return;
        } else {
            for ($i = 0; $i < $rows_count; $i++) {
                $r = rand(0, count($grid) - 1);
                $row = array_splice($grid, $r, 1);

                $ready_row = array();
                foreach ($row[0] as $e) {
                    array_push($ready_row, $e * $mult); 
                }

                array_push($ret, $ready_row);
            }
        }

        return $ret;
    }

    private function getPersonalAfisha($user, $session_tags, $interval) {
        $user_tags    = $user->getTagsList();
        $user_artists = $user->getArtistsListNormal();

        $period = $this->prepareTimeInterval($interval); 

        $likes = $this->getUserLikes(array(
            'user_id' => $user->getId(), 
            'start'   => $period['start'], 
            'end'     => $period['end'] 
        ));

        $actual_internal = $this->getActualInternalIndex(array( 'parse' => 1, 'start' => $period['start'], 'end' => $period['end'] ));

        $internal_weight = array();

        foreach ($actual_internal as $id => $e) {

            # Check dislike
            if (isset($likes[ $e->getId() ]) && $likes[ $e->getId() ]->getType() == 2) {
                continue;
            }

            # Calculate tag weight
            $weight = 0;

            $tags = array();
            $next_flag = 1;
            foreach ($e->getTagsNamesList() as $t) {
                if (isset($user_tags[$t]) && $t != 'russian') {
                     $tags[$t] = $user_tags[$t];
                } else {
                    $weight -= 10;
                }

                if (count($session_tags) > 0 && isset($session_tags[$t])) {
                    $next_flag = 0;
                }
            }

            if (count($session_tags) > 0 && $next_flag == 1)
                continue;

            arsort($tags);

            $i = 0;
            foreach ($tags as $t => $w) {
                $i++;
                if ($i <= 3) { 
                    $weight += $tags[$t] * 2;
                }
            }

            # Calculate name weight
            foreach ($e->getCleanArtistsList() as $a) {
                if (isset($user_artists[$a]) && $user_artists[$a] > 0) {
                    $weight *= $user_artists[$a] * 3;
                }
            }

            # Time penalty
            if (( $e->getStartTimestamp() - time() ) <= 60 * 60 * 24 * 30) {
                $weight *= 1.5;
            }

            if (( $e->getStartTimestamp() - time() ) >= 60 * 60 * 24 * 30 * 3) {
                $weight /= 3;
            }

            $e->setWeight($weight);

            if ($weight > 0) {
                array_push($internal_weight, $e);
            }
        }

        usort($internal_weight, function($a, $b) {
            if ($a->getWeight() == $b->getWeight())
                return 0;

            return ($b->getWeight() < $a->getWeight()) ? -1 : 1;
        });
        
        return $internal_weight;
    }

    public function getPersonalAfishaAction(Request $r) {
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $limit    = $r->get('limit');
        $offset   = $r->get('offset');
        $interval = $r->get('interval');

        if (!$user_id) {
            $answer = array( 'error' => 'no auth' );
            return new Response(json_encode($answer));
        }

        # Get user tags
        $user = $this->fetchUserById($user_id);

        $session_tags = $this->getSessionTags($session);

        # Process internal events
        $internal_weight = $this->getPersonalAfisha($user, $session_tags, $interval);

        $internal_weight = array_slice($internal_weight, $offset, $limit);

        $answer = array( 
            'done' => 1, 
            'events' => $this->serialIndexEvents($internal_weight) 
        );

        return new Response(json_encode($answer));
    }

    public function syncStatusAction(Request $r) {
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        if (!$user_id) {
            $answer = array( 'error' => 'no auth' );
            return new Response(json_encode($answer));
        }

        $em = $this->getDoctrine()->getManager();
        $sync_list = $em->createQuery("select p from EventGeneralBundle:Sync p where p.userId = :user_id")
            ->setParameter('user_id', $user_id)  
            ->getResult();

        if ($sync_list && isset($sync_list[0])) {
            $sync = $sync_list[0];
            $add = $sync->getAdditionalArray();
            $answer = array( 'done' => $sync->getStatus(), 'additional' => $add);
            return new Response(json_encode($answer));

        } else {
            $answer = array( 'error' => 'no sync' );
            return new Response(json_encode($answer));
        }
    }
  
    private function getGeneralEventsByTags($tags_hash, $offset, $limit) {
        $events = $this->getActualInternalIndex();    
        $pre_events = array();

        foreach ($events as $e) {
            foreach ($e->getTagsNamesList() as $t) {
                if (isset( $tags_hash[$t] )) {
                    array_push($pre_events, $e);
                    break;
                }
            }
        }

        usort($pre_events, function($a, $b) {
            if ($a->getCatalogRate() == $b->getCatalogRate()) {

                if ($a->getStartTimestamp() == $b->getStartTimestamp()) {
                    return 0;
                }

                return ($a->getStartTimestamp() < $b->getStartTimestamp()) ? -1 : 1;
            }

            return ($b->getCatalogRate() < $a->getCatalogRate()) ? -1 : 1;
        });

        return array_slice($pre_events, $offset, $limit);
    }

    public function getGeneralEventsAction(Request $r) {
        $offset = $r->get('offset') ? $r->get('offset') : 0;

        # Generate grid (calc need events)
        $grid = $this->generateGrid(3, 3);

        $ecount = 0;
        foreach ($grid as $row) {
            foreach ($row as $e) {
                $ecount++; 
            }
        }

        # Get events
        $session = $r->getSession();

        $tags = $this->getSessionTags($session);
        $events = array();

        if (count($tags) == 0) {
            $events = $this->getActualInternalIndex(array('order' => 'catalog_rate', 'limit' => $ecount, 'offset' => $offset));    
        } else {
            $events = $this->getGeneralEventsByTags($tags, $offset, $ecount);
        }
        
        $answer = array( 'grid' => $grid, 'events' => $this->serialIndexEvents($events) );
        return new Response(json_encode($answer));
    }

/* 
==============================================================================
                                AFISHA PAGE 
==============================================================================
*/

    public function afishaAction(Request $r) {
        // General info
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $user = array();
        $my_tags = array();
        $likes = array();

        if ($user_id) {
            $user = $this->fetchUserById($user_id);
            $my_tags = array_slice($user->getTagsListFull('sort'), 0, 50);

            $lperiod = $this->prepareTimeInterval('all'); 
            $likes = $this->getUserLikes(array(
                'user_id' => $user_id, 
                'start'   => $lperiod['start'], 
                'end'     => $lperiod['end'] 
            ));
        }

        // Get afisha events 
        $period = $this->prepareTimeInterval('14d'); 

        $events = $this->getActualInternalIndex(array(
            'start' => $period['start'],
            'end' => $period['end']
        ));    

        // Tags selected
        $tags = $this->getSessionTags($session);

        $pre_events = array();
        if (count($tags) > 0) {
            foreach ($events as $e) {
                foreach ($e->getTagsNamesList() as $t) {
                    if (isset( $tags[$t] )) {
                        array_push($pre_events, $e);
                        break;
                    }
                }
            }
        } else {
            $pre_events = $events;
        }

        // Mobile detect
        $mob = $this->get('mobile_detect');
        $template = 'EventGeneralBundle:Default:afisha.html.twig';
        if ($mob->isMobile()) {
            $template = 'EventGeneralBundle:Default:afisha.mob.html.twig';
        }

        return $this->render($template, array(
            'top' => 'afisha',
            'user_id' => $user_id,
            'user'    => $user,
            'likes'   => $likes,
            'popular_tags' => $this->getPopularTags(),
            'month_intervals' => $this->getMonthIntervals(),
            'events' => $pre_events,
            'tags_name_selected' => $tags,
            'my_tags' => $my_tags,
            'my_tags_short' => array_slice($my_tags, 0, 30),
        ));
    }

    public function getAfishaEventsAction(Request $r) {
        $interval = $r->get('interval');

        # Prepare interval
        $period = $this->prepareTimeInterval($interval); 

        # Get events
        $events = $this->getActualInternalIndex(array( 'start' => $period['start'], 'end' => $period['end'] ));    

        # Prepare tags
        $session = $r->getSession();
        $tags = $this->getSessionTags($session);

        $pre_events = array();
        if (count($tags) > 0) {
            foreach ($events as $e) {
                foreach ($e->getTagsNamesList() as $t) {
                    if (!$tags || $tags == '' || isset( $tags[$t] )) {
                        array_push($pre_events, $e);
                        break;
                    }
                }
            }
        } else {
            $pre_events = $events;
        }

        $answer = array( 'events' => $this->serialIndexEvents($pre_events) );
        return new Response(json_encode($answer));
    }

/* 
==============================================================================
                                SEARCH RESULTS PAGE 
==============================================================================
*/

    public function searchAction(Request $r) {
        // General info
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $user  = array();
        $likes = array();

        if ($user_id) {
            $user = $this->fetchUserById($user_id);

            $lperiod = $this->prepareTimeInterval('all'); 
            $likes = $this->getUserLikes(array(
                'user_id' => $user_id, 
                'start'   => $lperiod['start'], 
                'end'     => $lperiod['end'] 
            ));
        }

        // Prepare query
        $q = $r->get('query');
        $sort = $r->get('sort');
        $period = $this->prepareTimeInterval('all'); 

        $events = $this->searchEvents($q, $period, $sort);

        // Tags selected
        $tags = $this->getSessionTags($session);

        // Mobile detect
        $mob = $this->get('mobile_detect');
        $template = 'EventGeneralBundle:Default:search.html.twig';
        if ($mob->isMobile()) {
            $template = 'EventGeneralBundle:Default:search.mob.html.twig';
        }

        return $this->render($template, array(
            'top'     => 'afisha',
            'user_id' => $user_id,
            'user'    => $user,
            'events'  => $events,
            'query'   => $q,
            'sort'    => $sort,
            'month_intervals' => $this->getMonthIntervals(),
            'tags_name_selected' => $tags,
            'likes' => $likes,
        ));
    }

    private function searchEvents($query, $period, $sort) {
        $s = new \SphinxClient;
        $s->setServer("localhost", 9312);
        $s->setMatchMode(SPH_MATCH_EXTENDED);
        $s->setMaxQueryTime(3);

        $result = $s->query($query);

        $events = array();
        if ( $result != false && $result['total_found'] > 0) { 
            // Prepare results
            $ids = array();
            foreach ( $result["matches"] as $id => $info ) {
                $ids[$id] = $info['weight'];
            }

            // Fetch Actual Index Events
            $raw_events = $this->getActualInternalIndexByIds(
                array_keys($ids), 
                array( 
                    'parse' => 1, 
                    'start' => $period['start'], 
                    'end' => $period['end'] 
                )
            );

            if ($sort == 'date') {
                $events = $raw_events;
            } else {
                foreach ($ids as $k => $v) {
                    if (isset($raw_events[$k])) {
                        array_push($events, $raw_events[$k]);
                    }
                }
            }
        }

        return $events;
    }

    public function getSearchResultsAction(Request $r) {
        $q = $r->get('query');
        $sort = $r->get('sort');
        $interval = $r->get('interval');

        $period = $this->prepareTimeInterval($interval); 
        $events = $this->searchEvents($q, $period, $sort);

        $answer = array( 'events' => $this->serialIndexEvents($events) );
        return new Response(json_encode($answer));
    }

    public function searchAutocompleteAction(Request $r) {
        $q = $r->get('term');
        $sort = 'date';
        $period = $this->prepareTimeInterval('all'); 

        $events = $this->searchEvents($q, $period, $sort);

        if ( !$events || count($events) == 0 ) { 
            $answer = array( 'events' => array() );
            return new Response(json_encode($answer));
        }

        $answer = array( 'events' => array_slice($this->serialIndexEvents($events), 0, 5) );
        return new Response(json_encode($answer));
    }

/* 
==============================================================================
                                EVENT PAGE 
==============================================================================
*/

    public function eventAction(Request $r) {
        // General info
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $user = array();
        if ($user_id) {
            $user = $this->fetchUserById($user_id);
        }

        // Get event id
        $event_id = $r->get('event_id');
        $year = $r->get('year');
        $month = $r->get('month');

        $param = 'urlName';
        if (preg_match("/^(\d+)$/", $event_id)) {
            $param = 'id'; 
        }

        // Lookup event
        $dt_start = new \DateTime("$year-$month-01");
        $dt_end = clone $dt_start;
        $dt_end = $dt_end->add(new \DateInterval('P1M'));

        $em = $this->getDoctrine()->getManager();
        $event = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.start >= :start and p.start <= :end and p.$param = :event_id")
            ->setParameter('start', $dt_start->format('Y-m-d'))  
            ->setParameter('end', $dt_end->format('Y-m-d'))  
            ->setParameter('event_id', $event_id)  
            ->useResultCache(true, 60) 
            ->getResult();

        if (!$event || count($event) == 0) {
            throw $this->createNotFoundException('Event does not exist');
        } else {
            $event = $event[0];
        }

        $id = $event->getId();

        $event->howLong();

        // Lookup index info
        $index = $em->createQuery("select p from EventGeneralBundle:ActualInternalIndex p where p.internal_id = :id")
            ->setParameter('id', $id)  
            ->useResultCache(true, 60) 
            ->getSingleResult();

        // Prepare place info
        $place = json_decode( $index->getPlace() );

        // Prepare tickets info
        $tickets = $index->getTicketsList();

        // Get similar events
        $tags_list = str_replace(',', '|', $index->getTagsNames());
        $similar = $this->getSimilarEventsByTags($tags_list, array(
            'limit' => 6,
            'shuffle' => 0,
        ));

        // Get like & dislike
        $like = $em->createQuery("select p from EventGeneralBundle:UserLike p where p.indexId = :id and p.userId = :uid")
            ->setParameter('id', $index->getId())  
            ->setParameter('uid', $user_id)  
            ->getResult();

        if ($like && count($like) > 0) {
            $like = $like[0];
        }

        // Detect Mobile
        $mob = $this->get('mobile_detect');
        $template = 'EventGeneralBundle:Default:event.html.twig';
        if ($mob->isMobile()) {
            $template = 'EventGeneralBundle:Default:event.mob.html.twig';
        }

        return $this->render($template, array(
            'top' => 'event',
            'user_id' => $user_id,
            'user'    => $user,
            'event' => $event,
            'index' => $index,
            'place' => $place,
            'tickets' => $tickets,
            'similar' => $similar,
            'like' => $like,
        ));
    }

    private function getSimilarEventsByTags($tags, $params = null) {
        $q = "(@tags_names $tags)";        
        $sort = 'relevance';
        $period = $this->prepareTimeInterval('90d'); 

        $events = $this->searchEvents($q, $period, $sort);
        $events = array_values($events);

        if ($params['shuffle']) {
            shuffle($events);
        }

        if ($params['limit']) {
            $events = array_slice($events, 0, $params['limit']);
        }

        return $events;
    }

/* 
==============================================================================
                                PROFILE PAGE 
==============================================================================
*/

    public function profileAction(Request $r) {
        // General info
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $user = array();
        if ($user_id) {
            $user = $this->fetchUserById($user_id);
        } else {
            return $this->redirect($this->generateUrl('index'));
        }

        $period = $this->prepareTimeInterval('all'); 
        $likes = $this->getUserLikes(array(
            'user_id' => $user_id, 
            'start'   => $period['start'], 
            'end'     => $period['end'] 
        ));

        $only_likes = array();
        foreach ($likes as $id => $l) {
            if ($l->getType() == 1) {
                array_push($only_likes, $id);
            }
        }
        
        $like_events = $this->getActualInternalIndexByIds(
            $only_likes, 
            array( 
                'start' => $period['start'], 
                'end' => $period['end'] 
            )
        );

        // Detect Mobile
        $mob = $this->get('mobile_detect');
        $template = 'EventGeneralBundle:Default:profile.html.twig';
        if ($mob->isMobile()) {
            $template = 'EventGeneralBundle:Default:profile.mob.html.twig';
        }

        return $this->render($template, array(
            'top'     => 'profile',
            'user_id' => $user_id,
            'user'    => $user,
            'events' => $like_events,
            'likes' => $likes,
            'my_tags' => $user->getTagsListFull('sort'),
            'my_artists' => $user->getArtistsListNormal('sort'),
            'session' => $session,
        ));
    }

    public function likeEventAction(Request $r) {
        $id   = $r->get('id');
        $type = $r->get('type');

        $session = $r->getSession();
        $user_id = $session->get('user_id');

        if (!$user_id) {
            $answer = array( 'error' => 'no auth' );
            return new Response(json_encode($answer));
        }

        if (!$id) {
            $answer = array( 'error' => 'no index id' );
            return new Response(json_encode($answer));
        }

        if (!$type) {
            $answer = array( 'error' => 'no type' );
            return new Response(json_encode($answer));
        }

        $like_type = 1;
        if ($type == 'dislike') {
            $like_type = 2;
        }

        // Lookup index info
        $em = $this->getDoctrine()->getManager();
        $like = $em->createQuery("select p from EventGeneralBundle:UserLike p where p.indexId = :id and p.userId = :uid and p.type = :type")
            ->setParameter('id', $id)  
            ->setParameter('uid', $user_id)  
            ->setParameter('type', $like_type)  
            ->getResult();

        if ($like && count($like) > 0) {
            # Drop like
            $ul = $like[0];

            $em->remove($ul);
            $em->flush();

            $answer = array( 'done' => 1, 'action' => 'unset' );
            return new Response(json_encode($answer));

        } else {
            # Drop alternative type 
            $alter = 2;
            if ($type == 'dislike') {
                $alter = 1;
            }

            $alike = $em->createQuery("select p from EventGeneralBundle:UserLike p where p.indexId = :id and p.userId = :uid and p.type = :type")
                ->setParameter('id', $id)  
                ->setParameter('uid', $user_id)  
                ->setParameter('type', $alter)  
                ->getResult();

            if ($alike && count($alike) > 0) {
                $aul = $alike[0];

                $em->remove($aul);
                $em->flush();
            }

            # Create like
            $index = $em->createQuery("select p from EventGeneralBundle:ActualInternalIndex p where p.id = :id")
                ->setParameter('id', $id)  
                ->useResultCache(true, 60) 
                ->getSingleResult();

            $ul = new UserLike;
            $ul->setIndexId($id);
            $ul->setUserId($user_id);
            $ul->setType($like_type);
            $ul->setStart($index->getStart());

            $em->persist($ul);
            $em->flush();

            $answer = array( 'done' => 1, 'action' => 'set' );
            return new Response(json_encode($answer));
        }
    }

    public function updateUserEmailAction(Request $r) {
        $email = $r->get('email');

        $session = $r->getSession();
        $user_id = $session->get('user_id');

        if (!$user_id) {
            $answer = array( 'error' => 'no auth' );
            return new Response(json_encode($answer));
        }

        $user = $this->fetchUserById($user_id);

        $user->setEmail( $email );

        $em = $this->getDoctrine()->getManager();
        $em->persist($user);
        $em->flush();

        $answer = array( 'done' => 1 );
        return new Response(json_encode($answer));
    }

    public function updateUserSettingsAction(Request $r) {
        $email     = $r->get('email');
        $subscribe = $r->get('subscribe');

        $session = $r->getSession();
        $user_id = $session->get('user_id');

        if (!$user_id) {
            $answer = array( 'error' => 'no auth' );
            return new Response(json_encode($answer));
        }

        $user = $this->fetchUserById($user_id);

        $user->setEmail( $email );

        if ($subscribe) {
            $user->setSubscribe( 1 );
        }

        $em = $this->getDoctrine()->getManager();
        $em->persist($user);
        $em->flush();

        $answer = array( 'done' => 1 );
        return new Response(json_encode($answer));
    }

    public function subscribeAction(Request $r) {
        $user_id = $r->get('uid');

        // Get User
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:User');

        $user = $rep->find($user_id);

        if (!$user) {
            throw new \Exception('NO USER');
        }

        // Get current subscribe text 
        $em = $this->getDoctrine()->getManager();
        $subscribes = $em->createQuery("select p from EventGeneralBundle:Subscribe p where p.status = 1 order by p.id desc")
            ->getResult();

        $subscribe = $subscribes[0];

        // Don't forget 
        $period = $this->prepareTimeInterval('31d'); 
        $likes = $this->getUserLikes(array(
            'user_id' => $user_id, 
            'start'   => $period['start'], 
            'end'     => $period['end'] 
        ));

        $only_likes = array();
        foreach ($likes as $id => $l) {
            if ($l->getType() == 1) {
                array_push($only_likes, $id);
            }
        }
        
        $like_events = $this->getActualInternalIndexByIds(
            $only_likes, 
            array( 
                'start' => $period['start'], 
                'end' => $period['end'] 
            )
        );

        // Weekend
        $events_weekend = $this->getPersonalAfisha($user, null, 'weekend');
        $events_weekend = array_slice($events_weekend, 0, 4);

        $events = $this->getPersonalAfisha($user, null, 'all');
        $events = array_slice($events, 0, 4);
        
        return $this->render('EventGeneralBundle:Default:subscribe.html.twig', array(
            'user' => $user,
            'subscribe' => $subscribe,
            'like_events' => $like_events,
            'events_weekend' => $events_weekend,
            'events' => $events,
        ));
    }

    public function unsubscribeAction(Request $r) {
        $hash = $r->get('hash');

        $em = $this->getDoctrine()->getManager();
        $users = $em->createQuery("select p from EventGeneralBundle:User p where p.subscribeSecret = :hash")
            ->setParameter('hash', $hash)  
            ->getResult();

        $subscribe_error = 0;
        $user = array();
        $user_id = null;

        if (!$users || count($users) == 0) {
            $subscribe_error = 1;
        } else {
            $user = $users[0];
            $user->setSubscribe(0);

            $em = $this->getDoctrine()->getManager();
            $em->persist($user);
            $em->flush();

            $user_id = $user->getId();
        }

        return $this->render('EventGeneralBundle:Default:unsubscribe.html.twig', array(
            'top'     => 'index',
            'user'    => $user,
            'error'   => $subscribe_error,
            'user_id' => $user_id
        ));
    }

    public function subscribeTitleAction(Request $r) {
        $user_id = $r->get('uid');

        // Get User
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:User');

        $user = $rep->find($user_id);

        if (!$user) {
            throw new \Exception('NO USER');
        }

        // Don't forget 
        $period = $this->prepareTimeInterval('31d'); 
        $likes = $this->getUserLikes(array(
            'user_id' => $user_id, 
            'start'   => $period['start'], 
            'end'     => $period['end'] 
        ));

        $only_likes = array();
        foreach ($likes as $id => $l) {
            if ($l->getType() == 1) {
                array_push($only_likes, $id);
            }
        }
        
        $like_events = $this->getActualInternalIndexByIds(
            $only_likes, 
            array( 
                'start' => $period['start'], 
                'end' => $period['end'] 
            )
        );

        $like_events = array_slice($like_events, 0, 3);
        
        $events = $this->getPersonalAfisha($user, null, 'all');
        $events = array_slice($events, 0, 6);

        $all = array_merge($like_events, $events);

        $names = array();
        foreach ($all as $e) {
            array_push($names, $e->getName());
        }

        $names = array_unique($names);
        shuffle($names);
        $names = array_slice($names, 0, 3);

        return new Response(json_encode($names));
    }

}
