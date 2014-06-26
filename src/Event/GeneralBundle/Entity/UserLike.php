<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * UserLike
 */
class UserLike
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
    private $indexId;

    /**
     * @var integer
     */
    private $type;

    /**
     * @var \DateTime
     */
    private $start;


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
     * @return UserLike
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
     * Set indexId
     *
     * @param integer $indexId
     * @return UserLike
     */
    public function setIndexId($indexId)
    {
        $this->indexId = $indexId;

        return $this;
    }

    /**
     * Get indexId
     *
     * @return integer 
     */
    public function getIndexId()
    {
        return $this->indexId;
    }

    /**
     * Set type
     *
     * @param integer $type
     * @return UserLike
     */
    public function setType($type)
    {
        $this->type = $type;

        return $this;
    }

    /**
     * Get type
     *
     * @return integer 
     */
    public function getType()
    {
        return $this->type;
    }

    /**
     * Set start
     *
     * @param \DateTime $start
     * @return UserLike
     */
    public function setStart($start)
    {
        $this->start = $start;

        return $this;
    }

    /**
     * Get start
     *
     * @return \DateTime 
     */
    public function getStart()
    {
        return $this->start;
    }
}
