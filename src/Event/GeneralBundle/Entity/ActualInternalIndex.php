<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * ActualInternalIndex
 */
class ActualInternalIndex
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var string
     */
    private $name;

    /**
     * @var string
     */
    private $artists;

    /**
     * @var string
     */
    private $tags;

    /**
     * @var string
     */
    private $artistsTags;


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
     * Set name
     *
     * @param string $name
     * @return ActualInternalIndex
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
     * Set artists
     *
     * @param string $artists
     * @return ActualInternalIndex
     */
    public function setArtists($artists)
    {
        $this->artists = $artists;

        return $this;
    }

    /**
     * Get artists
     *
     * @return string 
     */
    public function getArtists()
    {
        return $this->artists;
    }

    /**
     * Set tags
     *
     * @param string $tags
     * @return ActualInternalIndex
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
     * Set artistsTags
     *
     * @param string $artistsTags
     * @return ActualInternalIndex
     */
    public function setArtistsTags($artistsTags)
    {
        $this->artistsTags = $artistsTags;

        return $this;
    }

    /**
     * Get artistsTags
     *
     * @return string 
     */
    public function getArtistsTags()
    {
        return $this->artistsTags;
    }

    public function getTagsList() {
        return array_filter( explode(',', $this->artistsTags) );
    }


    /**
     * @var integer
     */
    private $internal_id;


    /**
     * Set internal_id
     *
     * @param integer $internalId
     * @return ActualInternalIndex
     */
    public function setInternalId($internalId)
    {
        $this->internal_id = $internalId;

        return $this;
    }

    /**
     * Get internal_id
     *
     * @return integer 
     */
    public function getInternalId()
    {
        return $this->internal_id;
    }

    public function getArtistsList() {
        return array_filter( explode(',', $this->artists) );
    }
}
