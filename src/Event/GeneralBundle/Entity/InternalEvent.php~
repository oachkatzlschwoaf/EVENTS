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

    public function getHumanStartTime()
    {
        return $this->start->format('H:i');
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

    public function dropArtist($id) {
        $artist_arr = array_diff( explode(',', $this->artists), array($id) );
        $this->artists = implode(',', $artist_arr);
    }

    public function addArtist($id) {
        $artist_arr = explode(',', $this->artists);
        array_push($artist_arr, $id );
        $artist_arr = array_unique($artist_arr);
        $this->artists = implode(',', $artist_arr);
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

    /**
     * @var integer
     */
    private $catalogRate;


    /**
     * Set catalogRate
     *
     * @param integer $catalogRate
     * @return InternalEvent
     */
    public function setCatalogRate($catalogRate)
    {
        $this->catalogRate = $catalogRate;

        return $this;
    }

    /**
     * Get catalogRate
     *
     * @return integer 
     */
    public function getCatalogRate()
    {
        return $this->catalogRate;
    }

    private $catalog_small;
    private $catalog_medium;
    
    public function getCatalogSmall() {
        return $this->catalog_small;
    }

    public function setCatalogSmall($image) {
        $this->catalog_small = $image;
    }

    public function getCatalogMedium() {
        return $this->catalog_medium;
    }

    public function setCatalogMedium($image) {
        $this->catalog_medium = $image;
    }

    public function getUploadCatalogRootDir() {
        return __DIR__.'/../../../../web/'.$this->getUploadCatalogDir();
    }

    public function getUploadCatalogDir() {
        return 'uploads/catalog/';
    }

    public function uploadCatalogSmall() {
        if ($this->catalog_small) {
            $name = 'small_'.$this->getId();

            $this->catalog_small->move(
                $this->getUploadCatalogRootDir(), 
                $name.'.jpg'
            );
        }
    }

    /**
     * @ORM\PrePersist
     */
    public function processPrePersist()
    {
    }

    /**
     * @ORM\PostPersist
     */
    public function processPostPersist()
    {
    }

    /**
     * @ORM\PreUpdate
     */
    public function processPreUpdate()
    {
        // Add your code here
    }

    /**
     * @ORM\PostUpdate
     */
    public function processPostUpdate()
    {
    }
    /**
     * @var string
     */
    private $additionalInfo;


    /**
     * Set additionalInfo
     *
     * @param string $additionalInfo
     * @return InternalEvent
     */
    public function setAdditionalInfo($arr)
    {
        if (!$this->additionalInfo) {
            $this->additionalInfo = json_encode($arr);
        } else {
            $json = json_decode($this->additionalInfo);

            foreach ($arr as $k => $v) {
                $json->{$k} = $v;
            }

            $this->additionalInfo = json_encode($json);
        }

        return $this;
    }

    /**
     * Get additionalInfo
     *
     * @return string 
     */
    public function getAdditionalInfo()
    {
        return $this->additionalInfo;
    }

    public function getAdditional($param) {
        $json = json_decode($this->additionalInfo, 1);

        if (!isset($json[$param])) {
            return;
        }

        return $json[$param];
    }

    public function getAddParam($key) {
        $json = json_decode($this->additionalInfo);
        
        if (!isset($json->{$key})) {
            return;
        }

        return $json->{$key};
    }
    /**
     * @var string
     */
    private $urlName;


    /**
     * Set urlName
     *
     * @param string $urlName
     * @return InternalEvent
     */
    public function setUrlName($urlName)
    {
        $this->urlName = $urlName;

        return $this;
    }

    /**
     * Get urlName
     *
     * @return string 
     */
    public function getUrlName()
    {
        return $this->urlName;
    }

    public function shortStartHuman() {
        return $this->rus_date( $this->start->format('j F') );
    }

    public function fullStartHuman() {
        return $this->rus_date( $this->start->format('j F, H:i') );
    }

    public function fullEventDate() {
        return $this->rus_date( $this->start->format('j F (l), H:i') );
    }

    private function number($n, $titles) {
        $cases = array(2, 0, 1, 1, 1, 2);
        return $titles[($n % 100 > 4 && $n % 100 < 20) ? 2 : $cases[min($n % 10, 5)]];
    }

    public function howLong() {
        $now = new \DateTime;
        $dt  = $this->date;

        $diff = $dt->getTimestamp() - $now->getTimestamp();
        
        if ($diff <= 0) {
            return "событие прошло";
        } else if ($diff <= 86400) {
            return "сегодня";
        } else if ($diff > 86400 && $diff <= 172800) {
            return "завтра";
        } else if ($diff > 172800 && $diff <= 259200) {
            return "послезавтра";
        } else if ($diff > 259200 && $diff <= 1209600) {
            $d = round( $diff / 86400 );
            return "через $d ".$this->number($d, array("день", "дня", "дней"));
        } else if ($diff > 1209600 && $diff <= 1814400) {
            return "через две недели";
        } else if ($diff > 1814400 && $diff <= 2419200) {
            return "через месяц";
        } else if ($diff > 2419200 && $diff <= 5184000) {
            return "через два месяца";
        } else if ($diff > 5184000) {
            return 'больше трех месяцев до события';
        }
    }

    private function rus_date($date_in) {
        $translate = array(
            "am" => "дп",
            "pm" => "пп",
            "AM" => "ДП",
            "PM" => "ПП",
            "Monday" => "понедельник",
            "Mon" => "пн",
            "Tuesday" => "вторник",
            "Tue" => "вт",
            "Wednesday" => "среда",
            "Wed" => "ср",
            "Thursday" => "четверг",
            "Thu" => "чт",
            "Friday" => "пятница",
            "Fri" => "Пт",
            "Saturday" => "Суббота",
            "Sat" => "сб",
            "Sunday" => "воскресенье",
            "Sun" => "вс",
            "January" => "января",
            "Jan" => "янв",
            "February" => "февраля",
            "Feb" => "фев",
            "March" => "марта",
            "Mar" => "мар",
            "April" => "апреля",
            "Apr" => "апр",
            "May" => "мая",
            "May" => "мая",
            "June" => "июня",
            "Jun" => "июн",
            "July" => "июля",
            "Jul" => "июл",
            "August" => "августа",
            "Aug" => "авг",
            "September" => "сентября",
            "Sep" => "сен",
            "October" => "октября",
            "Oct" => "окт",
            "November" => "ноября",
            "Nov" => "ноя",
            "December" => "декабря",
            "Dec" => "дек",
            "st" => "ое",
            "nd" => "ое",
            "rd" => "е",
            "th" => "ое"
        );

        return strtr($date_in, $translate);
    }

    /**
     * @var integer
     */
    private $theme;


    /**
     * Set theme
     *
     * @param integer $theme
     * @return InternalEvent
     */
    public function setTheme($theme)
    {
        $this->theme = $theme;

        return $this;
    }

    /**
     * Get theme
     *
     * @return integer 
     */
    public function getTheme()
    {
        return $this->theme;
    }
    /**
     * @var integer
     */
    private $bigTheme;


    /**
     * Set bigTheme
     *
     * @param integer $bigTheme
     * @return InternalEvent
     */
    public function setBigTheme($bigTheme)
    {
        $this->bigTheme = $bigTheme;

        return $this;
    }

    /**
     * Get bigTheme
     *
     * @return integer 
     */
    public function getBigTheme()
    {
        return $this->bigTheme;
    }
    /**
     * @var integer
     */
    private $style;


    /**
     * Set style
     *
     * @param integer $style
     * @return InternalEvent
     */
    public function setStyle($style)
    {
        $this->style = $style;

        return $this;
    }

    /**
     * Get style
     *
     * @return integer 
     */
    public function getStyle()
    {
        return $this->style;
    }

    /**
     * @var string
     */
    private $video;


    /**
     * Set video
     *
     * @param string $video
     * @return InternalEvent
     */
    public function setVideo($video)
    {
        $this->video = $video;

        return $this;
    }

    /**
     * Get video
     *
     * @return string 
     */
    public function getVideo()
    {
        return $this->video;
    }

    public function getVideoList()
    {
        if (!$this->video) {
            return array();
        } else {
            return explode(',', $this->video);
        }
    }

    public function shortName($sym_count) {
        if (mb_strlen($this->name) > $sym_count) {
            return $this->tokenTruncate($this->name, $sym_count)."..."; 
        } else {
            return $this->name;
        }
    }

    private function tokenTruncate($string, $your_desired_width) {
        $parts = preg_split('/([\s\n\r]+)/u', $string, null, PREG_SPLIT_DELIM_CAPTURE);
        $parts_count = count($parts);

        $length = 0;
        $last_part = 0;
        for (; $last_part < $parts_count; ++$last_part) {
            $length += mb_strlen($parts[$last_part]);
            if ($length > $your_desired_width) { break; }
        }

        return implode(array_slice($parts, 0, $last_part));
    }

}
