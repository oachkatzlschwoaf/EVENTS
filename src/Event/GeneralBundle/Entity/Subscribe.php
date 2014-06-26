<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * Subscribe
 */
class Subscribe
{
    /**
     * @var integer
     */
    private $id;

    /**
     * @var integer
     */
    private $status;

    /**
     * @var string
     */
    private $text;


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
     * Set status
     *
     * @param integer $status
     * @return Subscribe
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
     * Set text
     *
     * @param string $text
     * @return Subscribe
     */
    public function setText($text)
    {
        $this->text = $text;

        return $this;
    }

    /**
     * Get text
     *
     * @return string 
     */
    public function getText()
    {
        return $this->text;
    }
}
