<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * UserAudioArtist
 */
class UserAudioArtist
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
    private $artistId;

    /**
     * @var string
     */
    private $artist;

    /**
     * @var string
     */
    private $tags;


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
     * @return UserAudioArtist
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
     * Set artistId
     *
     * @param integer $artistId
     * @return UserAudioArtist
     */
    public function setArtistId($artistId)
    {
        $this->artistId = $artistId;

        return $this;
    }

    /**
     * Get artistId
     *
     * @return integer 
     */
    public function getArtistId()
    {
        return $this->artistId;
    }

    /**
     * Set artist
     *
     * @param string $artist
     * @return UserAudioArtist
     */
    public function setArtist($artist)
    {
        $this->artist = $artist;

        return $this;
    }

    /**
     * Get artist
     *
     * @return string 
     */
    public function getArtist()
    {
        return $this->artist;
    }

    /**
     * Set tags
     *
     * @param string $tags
     * @return UserAudioArtist
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
    public function getTags()
    {
        return $this->tags;
    }
    /**
     * @var integer
     */
    private $count;


    /**
     * Set count
     *
     * @param integer $count
     * @return UserAudioArtist
     */
    public function setCount($count)
    {
        $this->count = $count;

        return $this;
    }

    /**
     * Get count
     *
     * @return integer 
     */
    public function getCount()
    {
        return $this->count;
    }
    /**
     * @var string
     */
    private $cleanArtist;


    /**
     * Set cleanArtist
     *
     * @param string $cleanArtist
     * @return UserAudioArtist
     */
    public function setCleanArtist($cleanArtist)
    {
        $this->cleanArtist = $cleanArtist;

        return $this;
    }

    /**
     * Get cleanArtist
     *
     * @return string 
     */
    public function getCleanArtist()
    {
        return $this->cleanArtist;
    }
}
