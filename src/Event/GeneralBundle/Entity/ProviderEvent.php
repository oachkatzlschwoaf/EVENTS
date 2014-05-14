<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * ProviderEvent
 */
class ProviderEvent
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
    private $providerId;

    /**
     * @var string
     */
    private $description;


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
     * @return ProviderEvent
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
     * Set providerId
     *
     * @param string $providerId
     * @return ProviderEvent
     */
    public function setProviderId($providerId)
    {
        $this->providerId = $providerId;

        return $this;
    }

    /**
     * Get providerId
     *
     * @return string 
     */
    public function getProviderId()
    {
        return $this->providerId;
    }

    /**
     * Set description
     *
     * @param string $description
     * @return ProviderEvent
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
     * Set date
     *
     * @param \DateTime $date
     * @return ProviderEvent
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
     * @return ProviderEvent
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
     * @return ProviderEvent
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
     * @var integer
     */
    private $status;

    /**
     * @var integer
     */
    private $provider;


    /**
     * Set status
     *
     * @param integer $status
     * @return ProviderEvent
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
     * Set provider
     *
     * @param integer $provider
     * @return ProviderEvent
     */
    public function setProvider($provider)
    {
        $this->provider = $provider;

        return $this;
    }

    /**
     * Get provider
     *
     * @return integer 
     */
    public function getProvider()
    {
        return $this->provider;
    }

    public function getStatusName()
    {
        if ($this->status == 0) {
            return "unmatched";
        } else if ($this->status == 1) {
            return "matched";
        } else if ($this->status == 2) {
            return "cancelled";
        } else if ($this->status == 3) {
            return "w/o place";
        } else if ($this->status == 4) {
            return "w/o internal";
        } else if ($this->status == 5) {
            return "outdated";
        } else {
            return "error";
        }
    }
    /**
     * @var string
     */
    private $link;


    /**
     * Set link
     *
     * @param string $link
     * @return ProviderEvent
     */
    public function setLink($link)
    {
        $this->link = $link;

        return $this;
    }

    /**
     * Get link
     *
     * @return string 
     */
    public function getLink()
    {
        return $this->link;
    }
    /**
     * @var string
     */
    private $placeText;

    /**
     * @var integer
     */
    private $place;


    /**
     * Set placeText
     *
     * @param string $placeText
     * @return ProviderEvent
     */
    public function setPlaceText($placeText)
    {
        $this->placeText = $placeText;

        return $this;
    }

    /**
     * Get placeText
     *
     * @return string 
     */
    public function getPlaceText()
    {
        return $this->placeText;
    }

    public function getCleanPlaceText()
    {
        $pt = $this->placeText;
        $pt = mb_strtolower( $pt, 'utf8' );
        $pt = preg_replace('/[\"\'\(\)]/', '', $pt);

        return $pt;
    }

    /**
     * Set place
     *
     * @param integer $place
     * @return ProviderEvent
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
}
