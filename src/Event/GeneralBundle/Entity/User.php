<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * User
 */
class User
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var string
     */
    private $email;

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
    private $additional;


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
     * Set email
     *
     * @param string $email
     * @return User
     */
    public function setEmail($email)
    {
        $this->email = $email;

        return $this;
    }

    /**
     * Get email
     *
     * @return string 
     */
    public function getEmail()
    {
        return $this->email;
    }

    /**
     * Set network
     *
     * @param integer $network
     * @return User
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
     * @return User
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
     * Set additional
     *
     * @param string $additional
     * @return User
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
    /**
     * @var string
     */
    private $name;

    /**
     * @var string
     */
    private $auth_info;

    /**
     * @var \DateTime
     */
    private $created_at;


    /**
     * Set name
     *
     * @param string $name
     * @return User
     */
    public function setName($name)
    {
        $this->name = $name;

        return $this;
    }

    /**
     * Get name
     *
     * @return string 
     */
    public function getName()
    {
        return $this->name;
    }

    /**
     * Set auth_info
     *
     * @param string $authInfo
     * @return User
     */
    public function setAuthInfo($authInfo)
    {
        $this->auth_info = $authInfo;

        return $this;
    }

    /**
     * Get auth_info
     *
     * @return string 
     */
    public function getAuthInfo()
    {
        return $this->auth_info;
    }

    /**
     * Set created_at
     *
     * @param \DateTime $createdAt
     * @return User
     */
    public function setCreatedAt() {
        $this->created_at = new \DateTime;

        return $this;
    }

    /**
     * Get created_at
     *
     * @return \DateTime 
     */
    public function getCreatedAt() {
        return $this->created_at;
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
    /**
     * @var string
     */
    private $tags;


    /**
     * Set tags
     *
     * @param string $tags
     * @return User
     */
    public function setTags($tags)
    {
        $this->tags = $tags;

        return $this;
    }

    /**
     * Get tags
     *
     * @return string 
     */
    public function getTags() {
        return $this->tags;
    }

    public function getTagsListNormal() {
        $tags = json_decode($this->tags);

        $sum = 0;
        foreach ($tags as $t => $v) {
            $sum += $v;
        }

        $ret;
        foreach ($tags as $t => $v) {
            if ($t != 'pop' && $t != 'russian') { 
                $p = $v / $sum;
                $ret[$t] = $p;
            }
        }

        return $ret;
    }
}
