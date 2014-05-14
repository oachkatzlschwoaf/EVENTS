<?php

namespace Event\GeneralBundle\Entity;

use Doctrine\ORM\Mapping as ORM;

/**
 * Genre
 */
class Genre
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
     * @return Genre
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
     * @var string
     */
    private $english_name;


    /**
     * Set english_name
     *
     * @param string $englishName
     * @return Genre
     */
    public function setEnglishName($englishName)
    {
        $this->english_name = $englishName;

        return $this;
    }

    /**
     * Get english_name
     *
     * @return string 
     */
    public function getEnglishName()
    {
        return $this->english_name;
    }
}
