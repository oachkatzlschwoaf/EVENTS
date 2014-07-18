<?php

namespace Event\GeneralBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\Controller;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

# Entities
use Event\GeneralBundle\Entity\InternalEvent;
use Event\GeneralBundle\Entity\InternalProvider;
use Event\GeneralBundle\Entity\Place;
use Event\GeneralBundle\Entity\Artist;
use Event\GeneralBundle\Entity\User;
use Event\GeneralBundle\Entity\Tag;
use Event\GeneralBundle\Entity\Subscribe;
use Event\GeneralBundle\Entity\AdminAction;

# Forms
use Event\GeneralBundle\Form\ProviderEventType; 
use Event\GeneralBundle\Form\InternalEventType; 
use Event\GeneralBundle\Form\PlaceType; 
use Event\GeneralBundle\Form\ArtistType; 

class AdminController extends Controller {

    private function processTags($tag_str) {
        $tag_arr = array_filter( explode(',', $tag_str ) );

        $em = $this->getDoctrine()->getManager();
        $tags = array();

        $to_add = array();
        foreach ($tag_arr as $t) {
            $tres = $em->createQuery("select p from EventGeneralBundle:Tag p where p.name = :name")
                ->setParameter('name', $t) 
                ->getResult();

            if ($tres && count($tres) > 0) {
                array_push($tags, $tres[0]->getId());
            } else {
                array_push($to_add, $t);
            }
        }

        foreach ($to_add as $t) {
            $tag = new Tag;
            $tag->setName($t);

            $em->persist($tag);
            $em->flush();

            array_push($tags, $tag->getId());
        }

        return $tags;
    }

    private function getTags() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Tag');

        $tags = $rep->findAll();
        
        $ret = array();
        foreach ($tags as $t) {
            $ret[ $t->getId() ] = $t;
        }

        return $ret;
    }

    private function getGenres() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Genre');

        $genres = $rep->findAll();
        
        $ret = array();
        foreach ($genres as $g) {
            $ret[ $g->getId() ] = $g->getName();
        }

        return $ret;
    }

    private function getCounters() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');

        $events = $rep->findAll();

        $counters = array();

        $em = $this->getDoctrine()->getManager();
        $counters['provider_unmatched'] = $em->createQuery("select count(p) from EventGeneralBundle:ProviderEvent p where p.status = :status")
            ->setParameter('status', 0) 
            ->getSingleScalarResult();

        $counters['provider_wo_place'] = $em->createQuery("select count(p) from EventGeneralBundle:ProviderEvent p where p.status = :status")
            ->setParameter('status', 3) 
            ->getSingleScalarResult();

        $counters['provider_wo_internal'] = $em->createQuery("select count(p) from EventGeneralBundle:ProviderEvent p where p.status = :status")
            ->setParameter('status', 4) 
            ->getSingleScalarResult();

        $counters['internal_wait'] = $em->createQuery("select count(p) from EventGeneralBundle:InternalEvent p where p.status = :status")
            ->setParameter('status', 0) 
            ->getSingleScalarResult();

        $counters['matches_wait'] = $em->createQuery("select count(p) from EventGeneralBundle:InternalProvider p where p.status = :status")
            ->setParameter('status', 0) 
            ->getSingleScalarResult();

        return $counters;
    }

    private function getProviders() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Provider');

        $providers = $rep->findAll();

        $ret = array();
        foreach ($providers as $p) {
            $ret[ $p->getId() ] = $p;
        }

        return $ret;
    }

    private function getPlaces() {
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Place');

        $places = $rep->findAll();

        $ret = array();
        foreach ($places as $p) {
            $ret[ $p->getId() ] = $p;
        }

        return $ret;
    }

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

    public function providerEventsAction(Request $r) {
        $status = $r->get('status');

        if (!$status) {
            $status = 0;
        }   

        $em = $this->getDoctrine()->getManager();
        
        # Get Provider events
        $events = $em->createQuery("select p from EventGeneralBundle:ProviderEvent p where p.status = :status order by p.date")
            ->setParameter('status', $status) 
            ->getResult();

        # Aggregate Provider events
        $agg_events = array();
        foreach ($events as $e) {
            $agg_events[ $e->getHumanDate() ][ $e->getId() ] = $e;
        }

        foreach ($agg_events as $dt => $arr) {
            uasort($arr, function($a, $b) {
                if ($a->getStart() == $b->getStart()) {
                    return 0;
                }
                return ($a->getStart() < $b->getStart()) ? -1 : 1;
            });
            
            $agg_events[$dt] = $arr;
        }

        $providers = $this->getProviders();
        $places    = $this->getPlaces();
        $counters  = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:unmatched.html.twig', array(
            'provider_status' => $status,
            'providers' => $providers,
            'agg_events' => $agg_events,
            'places'    => $places,
            'unmatched' => $events,
            'counters' => $counters,
        ));
    }

    public function providerEventAction(Request $r) {
        $e_id = $r->get('id'); 

        $em = $this->getDoctrine()->getManager();
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');

        $event = $rep->find($e_id);
        $form = $this->createForm(new ProviderEventType(), $event);

        if ($r->getMethod() == 'POST') {
            $form->handleRequest($r);

            if ($form->isValid()) {
                $em = $this->getDoctrine()->getManager();
                $em->persist($event);
                $em->flush();
            }
        }

        # Lookup for matched internal events
        $matched = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.providerId = :id")
            ->setParameter('id', $e_id) 
            ->getResult();

        $matched_events = array();
        foreach ($matched as $m) {
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:InternalEvent');
            $ie = $rep->find( $m->getInternalId() );
            
            $matched_events[ $m->getInternalId() ] = $ie;
        }

        # Tip for unmatched with internal
        $internal_events = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.date = :date order by p.start")
            ->setParameter('date', $event->getDate()) 
            ->getResult();

        # Tip for events w/o places
        $places = $this->getPlaces();
        $tips_place = array();

        foreach ($places as $p) {
            $keywords = explode(',', $p->getKeywords());
            array_push($keywords, $p->getName());
            
            foreach ($keywords as $k) {
                $k = mb_strtolower( $k, 'utf8' );
                $k = preg_replace('/[\"\'\(\)]/', '', $k);

                if (mb_strlen($k, 'utf8') > 3) {
                    $dist = levenshtein($event->getCleanPlaceText(), $k); 
                    $dist_p = abs( round( $dist * 100 / mb_strlen($event->getCleanPlaceText(), 'utf8') ) );

                    if ($dist_p < 50) {
                        $tips_place[ $p->getId() ]['dist'] = $dist_p;
                        $tips_place[ $p->getId() ]['name'] = $p->getName();
                    }
                }
            }
        }

        # Get tickets
        $tickets = $em->createQuery("select p from EventGeneralBundle:Ticket p where p.providerEvent = :event")
            ->setParameter('event', $e_id) 
            ->getResult();

        # Other stuff
        $providers = $this->getProviders();
        $counters  = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:provider_event.html.twig', array(
            'id'      => $e_id,
            'event'   => $event,
            'form'    => $form->createView(),
            'matched' => $matched,
            'matched_events' => $matched_events,
            'providers' => $providers,
            'places' => $places,
            'provider_status' => $event->getStatus(),
            'internal_events' => $internal_events,
            'tips_place' => $tips_place,
            'tickets' => $tickets,
            'counters' => $counters,
        ));
    }

    public function createInternalEventAction(Request $r) {
        $p_id = $r->get('provider_event'); 
        $format = $r->get('format'); 
        
        $em = $this->getDoctrine()->getManager();
        $check_link = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.providerId = :id")
            ->setParameter('id', $p_id) 
            ->getResult();
       
        if (count($check_link) > 0) {
            if ($format == 'json') {
                $answer = array( 'error' => 'event matched, cannot create internal' );
                return new Response(json_encode($answer));
            } else {
                return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
            } 
        }

        # Update Provider Event status
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');

        $pe = $rep->find($p_id);
        $pe->setStatus( 1 ); # matched

        # Check place status
        $internal_status = 0;
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Place');
        $place = $rep->find( $pe->getPlace() );

        if ($place->getStatus() == 0) {
            $internal_status = 2;
        }

        # Create Internal event
        $ie = new InternalEvent();
        $ie->setName( $pe->getName() );
        $ie->setDate( $pe->getDate() );
        $ie->setStart( $pe->getStart() );
        $ie->setDuration( $pe->getDuration() );
        $ie->setDescription( $pe->getDescription() );
        $ie->setPlace( $pe->getPlace() );
        $ie->setCatalogRate( 1 );
        $ie->setStatus( $internal_status ); # wait for approve

        $em->persist($ie);
        $em->persist($pe);
        $em->flush();

        # Create Internal Provider Link
        $ip = new InternalProvider();
        $ip->setStatus( 1 ); # approved
        $ip->setInternalId( $ie->getId() );
        $ip->setProviderId( $pe->getId() );

        $em->persist($ip);
        $em->flush();

        if ($format == 'json') {
            $answer = array( 'done' => 'internal created', 'internal_id' => $ie->getId() );
            return new Response(json_encode($answer));
        } else {
            return $this->redirect($this->generateUrl('internal_event', array('id' => $ie->getId())));
        }
    }

    public function internalEventAction(Request $r) {
        $e_id = $r->get('id'); 

        $em = $this->getDoctrine()->getManager();
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');

        $event = $rep->find($e_id);

        if (!$event) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $form = $this->createForm(new InternalEventType(), $event);

        if ($r->getMethod() == 'POST') {
            $form->handleRequest($r);

            $process_tags = $this->processTags( $event->getTags() );
            $event->setTags( implode(',', $process_tags) );

            if ($form->isValid()) {
                $em = $this->getDoctrine()->getManager();
                $em->persist($event);
                $em->flush();

                return $this->redirect($this->generateUrl('internal_event', array('id' => $event->getId())));
            }
        }

        # Lookup for Matches 
        $matched = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.internalId = :id")
            ->setParameter('id', $e_id) 
            ->getResult();

        $matched_events = array();
        $tickets = array();

        foreach ($matched as $m) {
            # Get Provider Events
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:ProviderEvent');
            $pe = $rep->find( $m->getProviderId() );
            
            $matched_events[ $m->getProviderId() ] = $pe;

            # Get Tickets
            $ts = $em->createQuery("select p from EventGeneralBundle:Ticket p where p.providerEvent = :event")
                ->setParameter('event', $m->getProviderId()) 
                ->getResult();
            
            $tickets[ $m->getProviderId() ] = $ts;
        }

        # Tooltip for match
        $tooltip_events = $em->createQuery("select p from EventGeneralBundle:ProviderEvent p where p.status = :status and p.start = :start and p.place = :place")
            ->setParameter('status', 4) 
            ->setParameter('start', $event->getStart()) 
            ->setParameter('place', $event->getPlace()) 
            ->getResult();

        # Artists
        $artists = $this->getArtists();
        $counters  = $this->getCounters();
        $places = $this->getPlaces();
        $providers = $this->getProviders();
        $tags = $this->getTags();

        return $this->render('EventGeneralBundle:Admin:internal_event.html.twig', array(
            'id'   => $e_id,
            'event' => $event,
            'form' => $form->createView(),
            'internal_status' => $event->getStatus(),
            'matched' => $matched,
            'matched_events' => $matched_events,
            'tickets' => $tickets,
            'providers' => $providers,
            'places' => $places,
            'artists' => $artists,
            'tags' => $tags,
            'tooltip_events' => $tooltip_events,
            'counters' => $counters,
        ));
    }

    public function internalEventsAction(Request $r) {
        $status = $r->get('status');
        $suspicious = $r->get('suspicious');

        if (!$status) {
            $status = 0;
        }   

        $places = $this->getPlaces();

        # Get Internal Events
        $em = $this->getDoctrine()->getManager();
        $events = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.status = :status order by p.date")
            ->setParameter('status', $status) 
            ->getResult();

        # Aggregate internal events
        $agg_events = array();
        foreach ($events as $e) {
            $agg_events[ $e->getHumanDate() ][ $e->getId() ] = $e;
        }

        foreach ($agg_events as $dt => $arr) {
            uasort($arr, function($a, $b) {
                if ($a->getStart() == $b->getStart()) {
                    return 0;
                }
                return ($a->getStart() < $b->getStart()) ? -1 : 1;
            });
            
            $agg_events[$dt] = $arr;
        }

        # Get Provider Events (in matched status) 
        $provider_events = $em->createQuery("select p from EventGeneralBundle:ProviderEvent p where p.status = :status order by p.date")
            ->setParameter('status', 1) 
            ->getResult();

        $pevents = array();
        foreach ($provider_events as $e) {
            $pevents[ $e->getId() ] = $e;
        }

        # Get matches 
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalProvider');

        $ipevents = $rep->findAll();

        $agg_ipevents = array();
        $agg_ipevents_total = array();
        foreach ($ipevents as $m) {
            $agg_ipevents[ $m->getInternalId() ][ $m->getStatus() ][ $m->getId() ] = $m; 

            if (!isset($agg_ipevents_total[ $m->getInternalId() ])) {
                $agg_ipevents_total[ $m->getInternalId() ] = 0;
            }

            $agg_ipevents_total[ $m->getInternalId() ]++;
        }

        # Get good matches
        $matches_count = array();
        foreach ($agg_ipevents as $e_id => $arr) {
            if (isset($agg_ipevents[ $e_id ][ 1 ])) {
                foreach ($agg_ipevents[ $e_id ][1] as $m_id => $m) {
                    if ( isset($pevents[$m->getProviderId()]) ) {
                        if (!isset($matches_count[ $e_id ])) {
                            $matches_count[ $e_id ] = 0;
                        }

                        $matches_count[ $e_id ]++;
                    }
                }

            } else {
                $matches_count[ $e_id ] = 0;
            }
        }

        # Suspicious: Check internal event 
        if ($suspicious) {
            foreach ($agg_events as $dt => $arr) {
                foreach ($arr as $e_id => $e) {
                    # Check settings
                    if ( isset($agg_ipevents[$e_id][1]) ) {
                         
                        # Check provider events status
                        $ok_flag = 0;
                        foreach ($agg_ipevents[$e_id][1] as $m_id => $v) {
                            if (isset($pevents[ $v->getProviderId() ])) {
                                $ok_flag = 1;
                            }
                        }
                         
                        if ($ok_flag) {
                            unset( $agg_events[ $e->getHumanDate() ][ $e_id ] );
                        }
                    }
                }
            }

            foreach ($agg_events as $dt => $arr) {
                if (count($agg_events[$dt]) == 0) {
                    unset( $agg_events[ $dt ] );
                }
            }
        }

        # Get other stuff
        $counters = $this->getCounters();
        $tags = $this->getTags();

        return $this->render('EventGeneralBundle:Admin:internal.html.twig', array(
            'internal_status' => $status,
            'agg_events' => $agg_events,
            'agg_ipevents' => $agg_ipevents,
            'agg_ipevents_total' => $agg_ipevents_total,
            'matches_count' => $matches_count,
            'events' => $events,
            'places' => $places,
            'tags' => $tags,
            'counters' => $counters,
        ));
    }

    public function matchEventAction(Request $r) {
        $p_id = $r->get('id');
        $i_id = $r->get('internal_id');
        $return_to_internal = $r->get('return_to_internal');
        $status = $r->get('status');
        $provider_event_status = $r->get('provider_event_status');
        $format = $r->get('format');

        if (!isset($status)) {
            $status = 1;
        }

        if (!isset($provider_event_status)) {
            $provider_event_status = 1;
        }

        # Check matched already?
        $em = $this->getDoctrine()->getManager();
        $check_link = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.providerId = :id")
            ->setParameter('id', $p_id) 
            ->getResult();
       
        if (count($check_link) > 0) {
            if ($format == 'json') {
                $answer = array( 'error' => 'event is already matched' );
                return new Response(json_encode($answer));
            } else {
                return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
            }
        }

        # Check events
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $pe = $rep->find( $p_id );

        if (!$ie || !$pe) {
            if ($format == 'json') {
                $answer = array( 'error' => 'internal or provider event not found' );
                return new Response(json_encode($answer));
            } else {
                return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
            }
        }

        # Make link
        $pe->setStatus( $provider_event_status ); 

        $ip = new InternalProvider();
        $ip->setStatus( $status ); 
        $ip->setInternalId( $ie->getId() );
        $ip->setProviderId( $pe->getId() );

        $em->persist($ip);
        $em->persist($pe);
        $em->flush();

        if ($format == 'json') {
            $answer = array( 'done' => 'matched', 'match_id' => $ip->getId() );
            return new Response(json_encode($answer));

        } elseif ($return_to_internal) {
            return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));

        } else {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }
    }

    public function cancelProviderEventAction(Request $r) {
        $p_id = $r->get('id');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $pe = $rep->find( $p_id );

        if (!$pe) {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }

        $pe->setStatus( 2 ); # cancelled

        $em = $this->getDoctrine()->getManager();
        $em->persist($pe);
        $em->flush();

        return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
    }

    public function matchedProviderEventAction(Request $r) {
        $p_id = $r->get('id');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $pe = $rep->find( $p_id );

        if (!$pe) {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }

        $pe->setStatus( 1 ); # matched

        $em = $this->getDoctrine()->getManager();
        $em->persist($pe);
        $em->flush();

        return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
    }

    public function unmatchProviderEventAction(Request $r) {
        $p_id = $r->get('id');
        $return_to_internal = $r->get('return_to_internal');
        $return_to_matches = $r->get('return_to_matches');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $pe = $rep->find( $p_id );

        if (!$pe) {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }

        $pe->setStatus( 0 ); # unmatched

        # Get Link
        $em = $this->getDoctrine()->getManager();
        $check_link = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.providerId = :id")
            ->setParameter('id', $p_id) 
            ->getResult();
       
        if (count($check_link) == 0) {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }

        $ip = $check_link[0];

        $em->remove($ip);

        $em->persist($pe);
        $em->flush();

        if (isset($return_to_internal)) {
            return $this->redirect($this->generateUrl('internal_event', array('id' => $return_to_internal)));
        } elseif (isset($return_to_matches)) {
            return $this->redirect($this->generateUrl('matches'));
        } else {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }
    }

    public function cancelInternalEventAction(Request $r) {
        $i_id = $r->get('id');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $ie->setStatus( 2 ); # cancelled

        $em = $this->getDoctrine()->getManager();
        $em->persist($ie);
        $em->flush();

        return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
    }

    public function waitInternalEventAction(Request $r) {
        $i_id = $r->get('id');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $ie->setStatus( 0 ); # wait

        $em = $this->getDoctrine()->getManager();
        $em->persist($ie);
        $em->flush();

        # Save admin action
        $log = array('event_id' => $ie->getId(), 'event_name' => $ie->getName()); 

        $aa = new AdminAction;
        $aa->setType(8); // Action: event cancelled 
        $aa->setInfo( json_encode($log) );
        $em->persist($aa);
        $em->flush();

        return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
    }

    public function workInternalEventAction(Request $r) {
        $i_id = $r->get('id');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $ie->setStatus( 1 ); # work

        $em = $this->getDoctrine()->getManager();
        $em->persist($ie);
        $em->flush();

        # Save admin action
        $log = array('event_id' => $ie->getId(), 'event_name' => $ie->getName()); 

        $aa = new AdminAction;
        $aa->setType(3); // Action: event to work 
        $aa->setInfo( json_encode($log) );
        $em->persist($aa);
        $em->flush();

        return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
    }

    public function workAllInternalEventsAction(Request $r) {
        $em = $this->getDoctrine()->getManager();
        $internal_events = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.status = :status")
            ->setParameter('status', 0) 
            ->getResult();

        foreach ($internal_events as $ie) {
            $ie->setStatus( 1 ); # work

            $em = $this->getDoctrine()->getManager();
            $em->persist($ie);
            $em->flush();
        }

        return $this->redirect($this->generateUrl('internal_events'));
    }

    public function changeMatchStatusAction(Request $r) {
        $m_id = $r->get('id');
        $status = $r->get('status');
        $return_to_matches = $r->get('return_to_matches');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalProvider');
        $m = $rep->find( $m_id );

        if (!$m) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $m->setStatus( $status );  

        $em = $this->getDoctrine()->getManager();
        $em->persist($m);
        $em->flush();

        if (isset($return_to_matches)) {
            return $this->redirect($this->generateUrl('matches'));
        } else {
            return $this->redirect($this->generateUrl('internal_event', array('id' => $m->getInternalId())));
        }
    }

    public function placesAction(Request $r) {
        $status = $r->get('status');

        $em = $this->getDoctrine()->getManager();

        if ($status == null) {
            $places = $em->createQuery("select p from EventGeneralBundle:Place p order by p.name")
                ->getResult();
            $status = -1;
        } else {
            $places = $em->createQuery("select p from EventGeneralBundle:Place p where p.status = :status order by p.name")
                ->setParameter('status', $status) 
                ->getResult();
        }

        # Other stuff
        $counters  = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:places.html.twig', array(
            'place_status' => $status,
            'places_selected' => 1,
            'places'   => $places,
            'counters' => $counters,
        ));
    }

    public function placeAction(Request $r) {
        $p_id = $r->get('id'); 

        $em = $this->getDoctrine()->getManager();
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Place');

        $place = $rep->find($p_id);
        $form = $this->createForm(new PlaceType(), $place);

        if ($r->getMethod() == 'POST') {
            $form->handleRequest($r);

            if ($form->isValid()) {
                $em = $this->getDoctrine()->getManager();
                $em->persist($place);
                $em->flush();

                return $this->redirect($this->generateUrl('place', array('id' => $p_id)));
            }
        }

        # Tip internal events
        $em = $this->getDoctrine()->getManager();
        $internal_events = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.place = :place order by p.date")
            ->setParameter('place', $p_id) 
            ->getResult();

        # Other stuff
        $counters  = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:place.html.twig', array(
            'places_selected' => 1,
            'place' => $place,
            'internal_events' => $internal_events,
            'form' => $form->createView(),
            'id' => $p_id,
            'counters' => $counters,
        ));
    }

    public function changePlaceStatusAction(Request $r) {
        $p_id = $r->get('id');
        $status = $r->get('status');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Place');
        $p = $rep->find( $p_id );

        if (!$p) {
            return $this->redirect($this->generateUrl('places'));
        }

        $p->setStatus( $status );  

        $em = $this->getDoctrine()->getManager();
        $em->persist($p);
        $em->flush();

        return $this->redirect($this->generateUrl('place', array('id' => $p_id)));
    }

    public function createPlaceAction(Request $r) {
        $p_id = $r->get('provider_event');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $p = $rep->find( $p_id );

        if (!$p) {
            return $this->redirect($this->generateUrl('provider_events'));
        }

        $place = new Place;

        $place->setName( $p->getPlaceText() );
        $place->setStatus( 1 ); # work
        $place->setZoom( 14 );

        $em = $this->getDoctrine()->getManager();
        $em->persist($place);
        $em->flush();

        $p->setPlace( $place->getId() );
        $p->setStatus( 4 );

        $em->persist($p);
        $em->flush();

        # Save admin action
        $log = array('place_id' => $place->getId(), 'place_name' => $place->getName()); 

        $aa = new AdminAction;
        $aa->setType(1); // Action: add place
        $aa->setInfo( json_encode($log) );
        $em->persist($aa);
        $em->flush();

        return $this->redirect($this->generateUrl('place', array('id' => $place->getId())));
    }

    public function changeProviderEventPlaceAction(Request $r) {
        $p_id = $r->get('id');
        $place_id = $r->get('place');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $pe = $rep->find( $p_id );

        if (!$pe) {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
        }

        # Check keywords
        if ($pe->getStatus() == 3) {
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:Place');
            $place = $rep->find( $place_id );

            if (!$place->isExistKeyword( $pe->getPlaceText() )) {
                $place->addKeyword( $pe->getPlaceText() );
            }
        }
        
        # Set place and save
        $pe->setPlace( $place_id ); 

        if ($pe->getStatus() == 3 || $pe->getStatus() == 0) {
            $pe->setStatus(4);
        }

        $em = $this->getDoctrine()->getManager();
        $em->persist($pe);
        $em->persist($place);
        $em->flush();

        return $this->redirect($this->generateUrl('provider_event', array('id' => $p_id)));
    }

    public function changeInternalEventPlaceAction(Request $r) {
        $i_id = $r->get('id');
        $place_id = $r->get('place');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
        }

        # Set place and save
        $ie->setPlace( $place_id ); 

        $em = $this->getDoctrine()->getManager();
        $em->persist($ie);
        $em->flush();

        return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
    }

    public function matchesAction(Request $r) {
        $status = $r->get('status');

        if (!$status) {
            $status = 0;
        }

        # Get Matches
        $em = $this->getDoctrine()->getManager();
        $matches = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.status = :status")
            ->setParameter('status', $status)  
            ->getResult();

        # Get Provider Events
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:ProviderEvent');
        $pevents = $rep->findAll();

        $provider_events = array();
        foreach ($pevents as $e) {
            $provider_events[ $e->getId() ] = $e;
        }

        # Get Internal Events
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ievents = $rep->findAll();

        $internal_events = array();
        foreach ($ievents as $e) {
            $internal_events[ $e->getId() ] = $e;
        }

        # Other stuff
        $counters  = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:matches.html.twig', array(
            'match_status' => $status,
            'matches' => $matches,
            'pevents' => $provider_events,
            'ievents' => $internal_events,
            'matches_selected' => 1,

            'counters' => $counters,
        ));
    }

    public function changeTicketStatusAction(Request $r) {
        $id = $r->get('id');
        $status = $r->get('status');
        $return_to_internal = $r->get('return_to_internal');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Ticket');
        $t = $rep->find( $id );

        if (!$t) {
            return $this->redirect($this->generateUrl('provider_events'));
        }

        $t->setStatus( $status );  

        $em = $this->getDoctrine()->getManager();
        $em->persist($t);
        $em->flush();

        if (isset($return_to_internal)) {
            return $this->redirect($this->generateUrl('internal_event', array('id' => $return_to_internal)));
        } else {
            return $this->redirect($this->generateUrl('provider_event', array('id' => $t->getProviderEvent())));
        }
    }
    
    public function artistsAction(Request $r) {
        $actual = $r->get('actual');

        $em = $this->getDoctrine()->getManager();
        $artists = $em->createQuery("select p from EventGeneralBundle:Artist p order by p.name")
            ->getResult();


        if ($actual) {
            $artist_hash = array();
            foreach ($artists as $a) {
                $artist_hash[ $a->getId() ] = $a; 
            }

            $em = $this->getDoctrine()->getManager();
            $internals = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.status = :status")
                ->setParameter('status', 1) # work 
                ->getResult();

            $a_i = array();
            foreach ($internals as $i) {
                $artist_in_event = $i->getArtistsList();

                foreach ($artist_in_event as $a) {
                    $a_i[ $a ] = $i;
                }
            }

            $artists = array();
            foreach ($a_i as $a => $v) {
                array_push($artists, $artist_hash[$a]);
            }

            uasort($artists, function($a, $b) {
                return strcmp($a->getName(), $b->getName());
            });
        }

        # Other stuff
        $counters  = $this->getCounters();
        $tags      = $this->getTags();

        return $this->render('EventGeneralBundle:Admin:artists.html.twig', array(
            'counters' => $counters,
            'artists' => $artists,
            'tags' => $tags,
            'artists_selected' => 1
        ));
    }

    public function addArtistAction(Request $r) {
        $artist = new Artist;
        $form = $this->createForm(new ArtistType(), $artist);

        # Save
        if ($r->getMethod() == 'POST') {
            $form->handleRequest($r);

            if ($form->isValid()) {
                $tags = $this->processTags( $artist->getTags() );
                $artist->setTags( implode(',', $tags) );

                $em = $this->getDoctrine()->getManager();
                $em->persist($artist);
                $em->flush();

                # Save admin action
                $log = array('artist_id' => $artist->getId(), 'artist_name' => $artist->getName()); 

                $aa = new AdminAction;
                $aa->setType(2); // Action: add artist 
                $aa->setInfo( json_encode($log) );
                $em->persist($aa);
                $em->flush();

                return $this->redirect($this->generateUrl('artist', array('id' => $artist->getId())));
            }
        }

        # Other stuff
        $counters  = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:add_artist.html.twig', array(
            'form'    => $form->createView(),
            'counters' => $counters,
            'artists_selected' => 1
        ));
    }

    public function genresAction(Request $r) {
        $q = $r->get('q');

        $genres = $this->getGenres();

        $answer = array();
        foreach ($genres as $id => $name) {
            if (preg_match("/$q/i", $name)) {
                array_push($answer, array( 'id' => $id, 'name' => $name, 'readonly' => true ));
            }
        }

        return new Response(json_encode($answer));
    }

    public function artistAction(Request $r) {
        $id = $r->get('id'); 

        $em = $this->getDoctrine()->getManager();
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Artist');

        $artist = $rep->find($id);
        
        $form = $this->createForm(new ArtistType(), $artist);

        # Save
        if ($r->getMethod() == 'POST') {
            $form->handleRequest($r);

            # Process tags
            $tags = $this->processTags( $artist->getTags() );
            $artist->setTags( implode(',', $tags) );

            if ($form->isValid()) {
                $em = $this->getDoctrine()->getManager();
                $em->persist($artist);
                $em->flush();
            }

            return $this->redirect($this->generateUrl('artist', array('id' => $artist->getId())));
        }

        # Get genres
        $genres = $this->getGenres();

        $artist_genres = array();

        foreach ($artist->getGenresList() as $g_id) {
            $artist_genres[$g_id] = $genres[$g_id];
        }

        # Other stuff
        $counters = $this->getCounters();
        $tags     = $this->getTags();

        return $this->render('EventGeneralBundle:Admin:artist.html.twig', array(
            'id' => $id,
            'artist' => $artist,
            'form'    => $form->createView(),
            'tags' => $tags,
            'artist_genres' => $artist_genres,
            'artists_selected' => 1,
            'counters' => $counters,
        ));
    }

    public function searchArtistsAction(Request $r) {
        $q = $r->get('q');

        $em = $this->getDoctrine()->getManager();
        $artists = $em->createQuery("select p from EventGeneralBundle:Artist p where p.name like :name")
            ->setParameter('name', "%$q%")  
            ->getResult();

        $answer = array();
        foreach ($artists as $a) {
            array_push($answer, array( 'id' => $a->getId(), 'name' => $a->getName(), 'readonly' => true ));
        }

        return new Response(json_encode($answer));
    }

    public function addArtistToInternalAction(Request $r) {
        $i_id = $r->get('id');
        $artist = $r->get('artist');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $artist_list = $ie->getArtistsList();

        $add_flag = 1;
        foreach ($artist_list as $a) {
            if ($a == $artist) {
                $add_flag = 0;
            }
        }

        if ($add_flag == 1) {
            array_push($artist_list, $artist);
            $ie->setArtists( implode(',', $artist_list) );

            $em = $this->getDoctrine()->getManager();
            $em->persist($ie);
            $em->flush();
        }

        return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
    }

    public function dropArtistFromInternalAction(Request $r) {
        $i_id = $r->get('id');
        $artist = $r->get('artist');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $i_id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $artist_list = $ie->getArtistsList();

        if(($key = array_search($artist, $artist_list)) !== false) {
            unset($artist_list[$key]);

            $ie->setArtists( implode(',', $artist_list) );

            $em = $this->getDoctrine()->getManager();
            $em->persist($ie);
            $em->flush();
        }

        return $this->redirect($this->generateUrl('internal_event', array('id' => $i_id)));
    }

    public function suggestMbidAction(Request $r) {
        $id = $r->get('id');
        $artist_name = $r->get('name');

        $artist = null;
        if ($id) {
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:Artist');
            $artist = $rep->find( $id );
        }

        $url = '';

        if( $curl = curl_init() ) {
            if ($artist) {
                $artist_name = $artist->getName();
            }

            $url = 'http://musicbrainz.org/ws/2/artist?query="'.urlencode($artist_name).'"';

            curl_setopt($curl, CURLOPT_URL, $url);
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            $out = curl_exec($curl);

            $http_code = curl_getinfo($curl, CURLINFO_HTTP_CODE);
            curl_close($curl);

            if ($http_code == 200) {
                $xml = simplexml_load_string($out);

                if ( $xml->{'artist-list'}->artist[0] ) {
                    $artist = $xml->{'artist-list'}->artist[0];  

                    $answer = array(
                        'mbid' => (string) $artist->attributes()->{'id'},
                        'name' => (string) $artist->{'name'},
                        'country' => (string) $artist->{'country'},
                    );

                    return new Response(json_encode($answer));
                }
            }
        }

        $answer = array( 'error' => 'not found', 'url' => $url );
        return new Response(json_encode($answer));
    }

    public function suggestTagsAction(Request $r) {
        $id = $r->get('id');
        $artist_name = $r->get('name');

        $artist = null;
        if ($id) {
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:Artist');
            $artist = $rep->find( $id );
        }

        $url = '';

        if( $curl = curl_init() ) {
            $url = $this->container->getParameter('lastfm_api_url').
                '?method=artist.gettoptags'.
                '&api_key='.
                $this->container->getParameter('lastfm_api_key').
                '&format=json';

            if ($artist) {
                if ($artist->getMbid()) {
                    $url .= '&mbid='.$artist->getMbid();
                } else {
                    $url .= '&artist='.urlencode($artist->getName());
                }
            } else {
                $url .= '&artist='.urlencode($artist_name);
            }

            curl_setopt($curl, CURLOPT_URL, $url);
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            $out = curl_exec($curl);

            $http_code = curl_getinfo($curl, CURLINFO_HTTP_CODE);
            curl_close($curl);

            if ($http_code == 200) {
                $json = json_decode($out); 

                if (!isset($json->error)) {

                    if (isset($json->toptags->tag)) {
                        $tags = $json->toptags->tag;

                        $answer = array();
                        foreach ($tags as $t) { 
                            if ($t->count > 30) {
                                array_push($answer, strtolower($t->name));
                            }

                        }

                        return new Response(json_encode($answer));
                    }
                }
            }
        }

        $answer = array( 'error' => 'not found', 'url' => $url );
        return new Response(json_encode($answer));
    }


    public function cropImageAction(Request $r) {
        $id = $r->request->get('id');

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $ie = $rep->find( $id );

        if (!$ie) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $image = $r->files->get('image');
        $type = $r->request->get('type');
        $image_type = $r->request->get('image_type');

        $x = $r->request->get('x');
        $y = $r->request->get('y');
        $w = $r->request->get('w');
        $h = $r->request->get('h');

        $iw = $r->request->get('iw');
        $ih = $r->request->get('ih');

        $t_w = $r->request->get('t_w');
        $t_h = $r->request->get('t_h');

        if ($image && $x && $y && $w && $h) {
            $web_path = $this->get('kernel')->getRootDir() . '/../web';
            $save_path = $web_path.'/uploads/'.$image_type.'/'.$type.'_'.$id.'.jpg';

            $im = new \Imagick( $image->getPathName() );  
            $geo = $im->getImageGeometry();  

            $pw = $geo['width'] / $iw;
            $ph = $geo['height'] / $ih;

            $x *= $pw;
            $y *= $ph;

            $w *= $pw;
            $h *= $ph;

            $im->cropImage($w, $h, $x, $y);
            $im->resizeImage($t_w, $t_h, \Imagick::FILTER_LANCZOS, 1);
            $im->writeImage($save_path);

            $em = $this->getDoctrine()->getManager();
            $ie->setAdditionalInfo(array( $image_type.'-image-'.$type => 1 ));
            $em->persist($ie);
            $em->flush();
        }

        return $this->redirect($this->generateUrl('internal_event', array('id' => $id)));
    }

    public function subscribeAction(Request $r) {
        $counters  = $this->getCounters();
        $id = $r->get('id'); 

        $em = $this->getDoctrine()->getManager();

        $subscribe = null;
        if ($id) {
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:Subscribe');

            $subscribe = $rep->find($id);
        }

        if ($r->getMethod() == 'POST') {
            $text = $r->get('text'); 

            if (!$id) {
                // Save new subscribe text
                $s = new Subscribe;
                $s->setText($text);
                $s->setStatus(1);

                $em->persist($s);
                $em->flush();

                return $this->redirect($this->generateUrl('admin_subscribe'));

            } else {
                $subscribe->setText($text);
                $subscribe->setStatus(1);

                $em->persist($subscribe);
                $em->flush();

                return $this->redirect($this->generateUrl('admin_subscribe')."?id=".$id);
            }
        }

        # Get subscribes
        $subscribes = $em->createQuery("select p from EventGeneralBundle:Subscribe p order by p.id desc")
            ->getResult();

        $max_id = 0;

        foreach ($subscribes as $s) {
            if ($s->getStatus() == 1 && $s->getId() > $max_id) {
                $max_id = $s->getId();
            }
        }

        return $this->render('EventGeneralBundle:Admin:subscribe.html.twig', array(
            'subscribe_selected' => 1, 
            'counters' => $counters,
            'subscribes' => $subscribes, 
            'publish_id' => $max_id, 
            'id' => $id, 
            'subscribe' => $subscribe, 
        ));
    }

    public function changeSubscribeStatusAction(Request $r) {
        $counters  = $this->getCounters();
        $id = $r->get('id'); 
        $status = $r->get('status'); 

        $subscribe = null;
        if ($id) {
            $rep = $this->getDoctrine()
                ->getRepository('EventGeneralBundle:Subscribe');

            $subscribe = $rep->find($id);
            $subscribe->setStatus($status);

            $em = $this->getDoctrine()->getManager();
            $em->persist($subscribe);
            $em->flush();
        }

        return $this->redirect($this->generateUrl('admin_subscribe'));
    }

    public function adminLogAction(Request $r) {
        $em = $this->getDoctrine()->getManager();
        
        # Get Provider events
        $log = $em->createQuery("select p from EventGeneralBundle:AdminAction p order by p.createdAt DESC")
            ->getResult();

        $agg_log = array();
        foreach ($log as $e) {
            $agg_log[ $e->getHumanDate() ][ $e->getId() ] = $e;
        }

        foreach ($agg_log as $dt => $arr) {
            uasort($arr, function($a, $b) {
                if ($a->getCreatedAt() == $b->getCreatedAt()) {
                    return 0;
                }
                return ($a->getCreatedAt() > $b->getCreatedAt()) ? -1 : 1;
            });

            $agg_log[$dt] = $arr;
        }

        $providers = $this->getProviders();
        $counters = $this->getCounters();

        return $this->render('EventGeneralBundle:Admin:admin_log.html.twig', array(
            'admin_log' => 1,
            'log' => $log,
            'agg_log' => $agg_log,
            'providers' => $providers,
            'counters' => $counters,
        ));
    }

    public function moveInternalAction(Request $r) {
        $id = $r->get('id');
        $to_id = $r->get('to_id');
        
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');
        $event = $rep->find( $id );

        if (!$event) {
            return $this->redirect($this->generateUrl('internal_events'));
        }

        $to_event = $rep->find( $to_id );

        if (!$to_event) {
            return $this->redirect($this->generateUrl('internal_event', array( 'id' => $id )));
        }

        # Change InternalProvider 
        $em = $this->getDoctrine()->getManager();
        $links = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.internalId = :id")
            ->setParameter('id', $id) 
            ->getResult();

        foreach ($links as $l) {
            $l->setInternalId($to_id);
            $em->persist($l);
        }

        # Remove Internal Event
        $em->remove($event);
        $em->flush();

        return $this->redirect($this->generateUrl('internal_event', array( 'id' => $to_id )));
    }

    public function internalProviderAction(Request $r) {
        $em = $this->getDoctrine()->getManager();
        
        # Get Provider events
        $internal_events = $em->createQuery("select p from EventGeneralBundle:InternalEvent p where p.status = :status order by p.date")
            ->setParameter('status', 0) 
            ->getResult();

        $provider_events = array();
        foreach ($internal_events as $ie) {
            $links = $em->createQuery("select p from EventGeneralBundle:InternalProvider p where p.internalId = :id")
                ->setParameter('id', $ie->getId()) 
                ->getResult();
            
            foreach ($links as $l) {
                $rep = $this->getDoctrine()
                    ->getRepository('EventGeneralBundle:ProviderEvent');

                $event = $rep->find($l->getProviderId());

                $provider_events[ $l->getInternalId() ] = $event;
            }
        }

        return $this->render('EventGeneralBundle:Admin:internal_provider.html.twig', array(
            'internal_events' => $internal_events,
            'provider_events' => $provider_events,
        ));
    }

    public function moveArtistAction(Request $r) {
        $id = $r->get('id');
        $to_id = $r->get('to_id');
        
        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:Artist');
        $artist = $rep->find( $id );

        if (!$artist) {
            return $this->redirect($this->generateUrl('artists'));
        }

        $to_artist = $rep->find( $to_id );

        if (!$to_artist) {
            return $this->redirect($this->generateUrl('artist', array( 'id' => $id )));
        }

        $rep = $this->getDoctrine()
            ->getRepository('EventGeneralBundle:InternalEvent');

        $internal_events = $rep->findAll();

        $em = $this->getDoctrine()->getManager();
        foreach ($internal_events as $ie) {
            foreach ($ie->getArtistsList() as $a) {
                if ($a == $id) {
                    $ie->dropArtist($id);
                    $ie->addArtist($to_id);

                    $em->persist($ie);
                    $em->flush();
                }
            }
        }

        # Remove Internal Event
        $em->remove($artist);
        $em->flush();

        return $this->redirect($this->generateUrl('artist', array( 'id' => $to_id )));
    }
}
