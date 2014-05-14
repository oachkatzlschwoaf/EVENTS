<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * InternalProvider
 */
class InternalProvider
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var integer
     */
    private $internalId;

    /**
     * @var integer
     */
    private $providerId;


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
     * Set internalId
     *
     * @param integer $internalId
     * @return InternalProvider
     */
    public function setInternalId($internalId)
    {
        $this->internalId = $internalId;

        return $this;
    }

    /**
     * Get internalId
     *
     * @return integer 
     */
    public function getInternalId()
    {
        return $this->internalId;
    }

    /**
     * Set providerId
     *
     * @param integer $providerId
     * @return InternalProvider
     */
    public function setProviderId($providerId)
    {
        $this->providerId = $providerId;

        return $this;
    }

    /**
     * Get providerId
     *
     * @return integer 
     */
    public function getProviderId()
    {
        return $this->providerId;
    }
    /**
     * @var integer
     */
    private $status;


    /**
     * Set status
     *
     * @param integer $status
     * @return InternalProvider
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
}
