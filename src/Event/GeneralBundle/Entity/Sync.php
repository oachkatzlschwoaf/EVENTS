<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * Sync
 */
class Sync
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var integer
     */
    private $userId;

    /**
     * @var integer
     */
    private $network;

    /**
     * @var string
     */
    private $networkId;

    /**
     * @var string
     */
    private $authInfo;

    /**
     * @var integer
     */
    private $status;

    /**
     * @var \DateTime
     */
    private $lastSync;


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
     * Set userId
     *
     * @param integer $userId
     * @return Sync
     */
    public function setUserId($userId)
    {
        $this->userId = $userId;

        return $this;
    }

    /**
     * Get userId
     *
     * @return integer 
     */
    public function getUserId()
    {
        return $this->userId;
    }

    /**
     * Set network
     *
     * @param integer $network
     * @return Sync
     */
    public function setNetwork($network)
    {
        $this->network = $network;

        return $this;
    }

    /**
     * Get network
     *
     * @return integer 
     */
    public function getNetwork()
    {
        return $this->network;
    }

    /**
     * Set networkId
     *
     * @param string $networkId
     * @return Sync
     */
    public function setNetworkId($networkId)
    {
        $this->networkId = $networkId;

        return $this;
    }

    /**
     * Get networkId
     *
     * @return string 
     */
    public function getNetworkId()
    {
        return $this->networkId;
    }

    /**
     * Set authInfo
     *
     * @param string $authInfo
     * @return Sync
     */
    public function setAuthInfo($authInfo)
    {
        $this->authInfo = $authInfo;

        return $this;
    }

    /**
     * Get authInfo
     *
     * @return string 
     */
    public function getAuthInfo()
    {
        return $this->authInfo;
    }

    /**
     * Set status
     *
     * @param integer $status
     * @return Sync
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
     * Set lastSync
     *
     * @param \DateTime $lastSync
     * @return Sync
     */
    public function setLastSync()
    {
        $this->lastSync = new \DateTime;

        return $this;
    }

    /**
     * Get lastSync
     *
     * @return \DateTime 
     */
    public function getLastSync()
    {
        return $this->lastSync;
    }


    public function isLastSyncActual()
    {
        $dt = new \DateTime;

        $diff = $dt->getTimestamp() - $this->lastSync->getTimestamp();

        #if ($diff > 60 * 60 * 24) {
        if ($diff > 60) {
            return 0;
        }

        return 1;
    }


    /**
     * @var string
     */
    private $additional;


    /**
     * Set additional
     *
     * @param string $additional
     * @return Sync
     */
    public function setAdditional($additional)
    {
        $this->additional = $additional;

        return $this;
    }

    /**
     * Get additional
     *
     * @return string 
     */
    public function getAdditional()
    {
        return $this->additional;
    }
}
