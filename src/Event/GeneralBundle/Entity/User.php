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

    public function getFirstName()
    {
        $arr = explode(' ', $this->name);
        if ($arr[0]) {
            return $arr[0];
        } else {
            return $this->name;
        }
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

    public function getTagsList() {
        return json_decode($this->tags, 1);
    }

    public function getTagsListFull($sort = null) {
        if (!$this->tagsFull) {
            return array();
        }

        if (!$sort) {
            return json_decode($this->tagsFull, 1);
        } else {
            $tags = json_decode($this->tagsFull, 1);
            arsort($tags);

            return $tags;
        }
    }

    public function getTagsListNormal($sort = null) {
        if (!$sort) {
            return json_decode($this->tagsNormal, 1);
        } else {
            $tags = json_decode($this->tagsNormal, 1);
            arsort($tags);

            return $tags;
        }
    }

    public function getArtistsListNormal($sort = null) {
        if (!$sort) {
            return json_decode($this->artistsNormal, 1);
        } else {
            $tags = json_decode($this->artistsNormal, 1);
            arsort($tags);

            return $tags;
        }
    }

    /**
     * @var string
     */
    private $tagsFull;


    /**
     * Set tagsFull
     *
     * @param string $tagsFull
     * @return User
     */
    public function setTagsFull($tagsFull)
    {
        $this->tagsFull = $tagsFull;

        return $this;
    }

    /**
     * Get tagsFull
     *
     * @return string 
     */
    public function getTagsFull()
    {
        return $this->tagsFull;
    }

    public function setAdditionalInfo($key, $val) {
        $add = $this->additional;

        if ($add) {
            $json = json_decode($add, 1);
            $json[$key] = $val;

            $json_str = json_encode($json);
            $this->additional = $json_str;
            
            return 1; 
        }
    }

    public function getAdditionalInfo($what) {
        $add = $this->additional;

        if ($add) {
            $json = json_decode($add, 1);
            
            return $json[$what]; 
        }
    }
    /**
     * @var string
     */
    private $tagsNormal;

    /**
     * @var string
     */
    private $artistsNormal;


    /**
     * Set tagsNormal
     *
     * @param string $tagsNormal
     * @return User
     */
    public function setTagsNormal($tagsNormal)
    {
        $this->tagsNormal = $tagsNormal;

        return $this;
    }

    /**
     * Get tagsNormal
     *
     * @return string 
     */
    public function getTagsNormal()
    {
        return $this->tagsNormal;
    }

    /**
     * Set artistsNormal
     *
     * @param string $artistsNormal
     * @return User
     */
    public function setArtistsNormal($artistsNormal)
    {
        $this->artistsNormal = $artistsNormal;

        return $this;
    }

    /**
     * Get artistsNormal
     *
     * @return string 
     */
    public function getArtistsNormal()
    {
        return $this->artistsNormal;
    }
    /**
     * @var integer
     */
    private $subscribe;


    /**
     * Set subscribe
     *
     * @param integer $subscribe
     * @return User
     */
    public function setSubscribe($subscribe)
    {
        $this->subscribe = $subscribe;

        return $this;
    }

    /**
     * Get subscribe
     *
     * @return integer 
     */
    public function getSubscribe()
    {
        return $this->subscribe;
    }
    /**
     * @var integer
     */
    private $subscribeSecret;


    /**
     * Set subscribeSecret
     *
     * @param integer $subscribeSecret
     * @return User
     */
    public function setSubscribeSecret($subscribeSecret)
    {
        $this->subscribeSecret = $subscribeSecret;

        return $this;
    }

    /**
     * Get subscribeSecret
     *
     * @return integer 
     */
    public function getSubscribeSecret()
    {
        return $this->subscribeSecret;
    }
}
