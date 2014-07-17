<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * AdminAction
 */
class AdminAction
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var integer
     */
    private $type;

    /**
     * @var string
     */
    private $info;

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
     * Set type
     *
     * @param integer $type
     * @return AdminAction
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
     * Set info
     *
     * @param string $info
     * @return AdminAction
     */
    public function setInfo($info)
    {
        $this->info = $info;

        return $this;
    }

    /**
     * Get info
     *
     * @return string 
     */
    public function getInfo()
    {
        return $this->info;
    }

    /**
     * Set createdAt
     *
     * @param \DateTime $createdAt
     * @return AdminAction
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

    public function getHumanDateTime()
    {
        return $this->createdAt->format('d.m.Y H:i');
    }

    public function getHumanDate()
    {
        return $this->createdAt->format('d.m.Y');
    }

    /**
     * @ORM\PrePersist
     */
    public function processPrePersist()
    {
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

    public function getInfoVal($param) {
        $json = json_decode($this->info, 1);

        if (!isset($json[$param])) {
            return;
        }

        return $json[$param];
    }
}
