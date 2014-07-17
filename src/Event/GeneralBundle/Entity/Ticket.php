<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * Ticket
 */
class Ticket
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var integer
     */
    private $providerEvent;

    /**
     * @var string
     */
    private $sector;

    /**
     * @var integer
     */
    private $priceMin;

    /**
     * @var integer
     */
    private $priceMax;


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
     * Set providerEvent
     *
     * @param integer $providerEvent
     * @return Ticket
     */
    public function setProviderEvent($providerEvent)
    {
        $this->providerEvent = $providerEvent;

        return $this;
    }

    /**
     * Get providerEvent
     *
     * @return integer 
     */
    public function getProviderEvent()
    {
        return $this->providerEvent;
    }

    /**
     * Set sector
     *
     * @param string $sector
     * @return Ticket
     */
    public function setSector($sector)
    {
        $this->sector = $sector;

        return $this;
    }

    /**
     * Get sector
     *
     * @return string 
     */
    public function getSector()
    {
        return $this->sector;
    }

    /**
     * Set priceMin
     *
     * @param integer $priceMin
     * @return Ticket
     */
    public function setPriceMin($priceMin)
    {
        $this->priceMin = $priceMin;

        return $this;
    }

    /**
     * Get priceMin
     *
     * @return integer 
     */
    public function getPriceMin()
    {
        return $this->priceMin;
    }

    /**
     * Set priceMax
     *
     * @param integer $priceMax
     * @return Ticket
     */
    public function setPriceMax($priceMax)
    {
        $this->priceMax = $priceMax;

        return $this;
    }

    /**
     * Get priceMax
     *
     * @return integer 
     */
    public function getPriceMax()
    {
        return $this->priceMax;
    }
    /**
     * @var integer
     */
    private $status;


    /**
     * Set status
     *
     * @param integer $status
     * @return Ticket
     */
    public function setStatus($status)
    {
        $this->status = $status;

        return $this;
    }

    /**
     * Get status
     *
     * @return integer 
     */
    public function getStatus()
    {
        return $this->status;
    }
    /**
     * @var \DateTime
     */
    private $createdAt;


    /**
     * Set createdAt
     *
     * @param \DateTime $createdAt
     * @return Ticket
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
    public function processPrePersist()
    {
        // Add your code here
    }

    /**
     * @ORM\PostPersist
     */
    public function processPostPersist()
    {
        $this->setCreatedAt();
    }

    /**
     * @ORM\PreUpdate
     */
    public function processPreUpdate()
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
