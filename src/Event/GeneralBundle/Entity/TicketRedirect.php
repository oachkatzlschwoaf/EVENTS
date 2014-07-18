<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * TicketRedirect
 */
class TicketRedirect
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var integer
     */
    private $ticket;

    /**
     * @var integer
     */
    private $event;

    /**
     * @var \DateTime
     */
    private $createdAt;


    /**
     * Get id
     *
     * @return integer 
     */
    public function getId()
    {
        return $this->id;
    }

    /**
     * Set ticket
     *
     * @param integer $ticket
     * @return TicketRedirect
     */
    public function setTicket($ticket)
    {
        $this->ticket = $ticket;

        return $this;
    }

    /**
     * Get ticket
     *
     * @return integer 
     */
    public function getTicket()
    {
        return $this->ticket;
    }

    /**
     * Set event
     *
     * @param integer $event
     * @return TicketRedirect
     */
    public function setEvent($event)
    {
        $this->event = $event;

        return $this;
    }

    /**
     * Get event
     *
     * @return integer 
     */
    public function getEvent()
    {
        return $this->event;
    }

    /**
     * Set createdAt
     *
     * @param \DateTime $createdAt
     * @return TicketRedirect
     */
    public function setCreatedAt() {
        $this->createdAt = new \DateTime;

        return $this;
    }

    /**
     * Get createdAt
     *
     * @return \DateTime 
     */
    public function getCreatedAt()
    {
        return $this->createdAt;
    }

    /**
     * @ORM\PrePersist
     */
    public function processPrePersist() {
        $this->setCreatedAt();
    }

    /**
     * @ORM\PostPersist
     */
    public function processPostPersist()
    {
        // Add your code here
    }

    /**
     * @ORM\PostUpdate
     */
    public function processPostUpdate()
    {
        // Add your code here
    }
}
