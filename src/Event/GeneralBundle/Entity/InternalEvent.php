<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * InternalEvent
 */
class InternalEvent
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
     * @var \DateTime
     */
    private $date;

    /**
     * @var \DateTime
     */
    private $start;

    /**
     * @var integer
     */
    private $duration;

    /**
     * @var string
     */
    private $description;

    /**
     * @var integer
     */
    private $status;


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
     * @return InternalEvent
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
     * Set date
     *
     * @param \DateTime $date
     * @return InternalEvent
     */
    public function setDate($date)
    {
        $this->date = $date;

        return $this;
    }

    /**
     * Get date
     *
     * @return \DateTime 
     */
    public function getDate()
    {
        return $this->date;
    }

    public function getHumanDate()
    {
        return $this->date->format('d.m.Y');
    }

    public function getHumanStart()
    {
        return $this->start->format('d.m.Y H:i');
    }

    /**
     * Set start
     *
     * @param \DateTime $start
     * @return InternalEvent
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

    /**
     * Set duration
     *
     * @param integer $duration
     * @return InternalEvent
     */
    public function setDuration($duration)
    {
        $this->duration = $duration;

        return $this;
    }

    /**
     * Get duration
     *
     * @return integer 
     */
    public function getDuration()
    {
        return $this->duration;
    }

    /**
     * Set description
     *
     * @param string $description
     * @return InternalEvent
     */
    public function setDescription($description)
    {
        $this->description = $description;

        return $this;
    }

    /**
     * Get description
     *
     * @return string 
     */
    public function getDescription()
    {
        return $this->description;
    }

    /**
     * Set status
     *
     * @param integer $status
     * @return InternalEvent
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

    public function getStatusName()
    {
        if ($this->status == 0) {
            return "wait for approve";
        } else if ($this->status == 1) {
            return "work";
        } else if ($this->status == 2) {
            return "cancelled";
        } else if ($this->status == 3) {
            return "outdated";
        } else {
            return "error";
        }
    }
    /**
     * @var integer
     */
    private $place;


    /**
     * Set place
     *
     * @param integer $place
     * @return InternalEvent
     */
    public function setPlace($place)
    {
        $this->place = $place;

        return $this;
    }

    /**
     * Get place
     *
     * @return integer 
     */
    public function getPlace()
    {
        return $this->place;
    }
    /**
     * @var string
     */
    private $artists;


    /**
     * Set artists
     *
     * @param string $artists
     * @return InternalEvent
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

    public function getArtistsList() {
        return array_filter( explode(',', $this->artists) );
    }

    public function getArtistsCount() {
        return count( array_filter( explode(',', $this->artists) ) );
    }
    /**
     * @var string
     */
    private $tags;


    /**
     * Set tags
     *
     * @param string $tags
     * @return InternalEvent
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

    public function getTagsList() {
        return array_filter( explode(',', $this->tags) );
    }

}
