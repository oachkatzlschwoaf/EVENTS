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

# Forms
use Event\GeneralBundle\Form\ProviderEventType; 
use Event\GeneralBundle\Form\InternalEventType; 
use Event\GeneralBundle\Form\PlaceType; 
use Event\GeneralBundle\Form\ArtistType; 

# Services
use Event\GeneralBundle\VkApi;

class DefaultController extends Controller {

    private function getArtists() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Artist');

        $artists = $rep->findAll();

        $ret = array();
        foreach ($artists as $a) {
            $ret[ $a->getId() ] = $a;
        }

        return $ret;
    }


    private function getUserArtistsList($user_id) {
        $em = $this->getDoctrine()->getManager();
        $user_audios = $em->createQuery("select p from EventGeneralBundle:UserAudio p where p.userId = :user_id")
            ->setParameter('user_id', $user_id)  
            ->getResult();
    
        $user_artists = array();
        if ($user_audios && count($user_audios) > 0) {
            foreach ($user_audios as $ua) {
                if (!isset($user_artists[ $ua->getArtist() ])) {
                    $user_artists[ $ua->getArtist() ] = 0; 
                }
           
                $user_artists[ $ua->getArtist() ]++; 
            }
        }

        return $user_artists;
    }

    private function getActualInternalIndex() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ActualInternalIndex');

        $index = $rep->findAll();
        
        $ret = array();
        foreach ($index as $i) {
            $ret[ $i->getInternalId() ] = $i;
        }

        return $ret;
    }


    private function getTags() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Tag');

        $tags = $rep->findAll();
        
        $ret = array();
        foreach ($tags as $t) {
            $ret[ $t->getName() ] = $t;
        }

        return $ret;
    }

    private function getTagsIds($tags_to_find) {
        $tags = $this->getTags();
        $tags_by_id = array();

        foreach ($tags_to_find as $t => $v) {
            if (isset($tags[$t])) {
                $tags_by_id[ $tags[$t]->getId() ] = $v;
            };
        }

        return $tags_by_id;
    }

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

        $em = $this->getDoctrine()->getManager();
        $em->persist($user);
        $em->flush();

        return $user;
    }

    private function fetchUserById($id) {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:User');

        return $rep->find($id);
    }

    private function fetchUser($network, $network_id, $auth) {
        $em = $this->getDoctrine()->getManager();
        $users = $em->createQuery("select p from EventGeneralBundle:User p where p.network = :network and p.networkId = :network_id")
            ->setParameter('network', $network)  
            ->setParameter('network_id', $network_id)  
            ->getResult();
        
        if ($users && count($users) > 0) {
            return $users[0];
        } else {
            if ($network == $this->container->getParameter('networks.vkontakte.id')) {
                $user = $this->registerVkUser($network_id, $auth);
                return $user;
            }
        }

        return;
    }

    public function indexAction(Request $r) {
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        $sync = array();

        if ($user_id) {
            // Check sync status 
            $em = $this->getDoctrine()->getManager();

            $sync_list = $em->createQuery("select p from EventGeneralBundle:Sync p where p.userId = :user_id")
                ->setParameter('user_id', $user_id)  
                ->getResult();

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
        }

        return $this->render('EventGeneralBundle:Default:index.html.twig', array(
            'user_id' => $user_id,
            'session' => $session,
            'sync'    => $sync,
        ));
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

            if($http_code != 200) {
                # TODO: Auth Error handler!
                throw new \Exception('AUTH ERROR');
            } else {
                # Check user and register
                $auth_info = json_decode($out);

                $user = $this->fetchUser($network, $auth_info->user_id, $auth_info);

                if (!$user) {
                    throw new \Exception('USER ERROR');
                }
            }

            curl_close($curl);

            $session = $r->getSession();

            $session->set('user_id', $user->getId());
            $session->set('network', $network);
            $session->set('network_id', $user->getNetworkId());
            $session->set('access_token', $auth_info->access_token);
        }

        return $this->redirect($this->generateUrl('index'));
    }

    public function getPersonalAfishaAction(Request $r) {
        $session = $r->getSession();
        $user_id = $session->get('user_id');

        if (!$user_id) {
            $answer = array( 'error' => 'no auth' );
            return new Response(json_encode($answer));
        }

        $user = $this->fetchUserById($user_id);

        $user_tags    = $user->getTagsListNormal();
        $user_tags_id = $this->getTagsIds($user_tags);
        $user_artists = $this->getUserArtistsList($user_id);

        # Process internal events
        $actual_internal = $this->getActualInternalIndex();
        $artists = $this->getArtists();

        $internal_weight = array();

        foreach ($actual_internal as $id => $e) {
            $event = array();

            $event['id']     = $id;
            $event['name']   = $e->getName();
            $event['weight'] = 0;

            # Calculate tag weight
            $weight = 0;

            $tags = array();
            foreach ($e->getTagsList() as $t) {
                if (isset($user_tags_id[$t])) {
                     $tags[$t] = $user_tags_id[$t];
                }
            }

            arsort($tags);

            $i = 0;
            foreach ($tags as $t => $w) {
                $i++;
                if ($i > 5)
                    break;

                $weight += $tags[$t];
            }

            # Calculate name weight
            foreach ($e->getArtistsList() as $a) {
                if (isset($user_artists[$a]) && $user_artists[$a] > 0) {
                    $weight *= $user_artists[$a];
                }
            }

            $event['weight'] = $weight;

            array_push($internal_weight, $event);
        }

        $answer = array( 'done' => 1, 'internal_weight' => $internal_weight );
        return new Response(json_encode($answer));
    }
}
