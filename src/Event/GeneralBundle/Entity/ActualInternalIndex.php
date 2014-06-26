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

    public function getFullTagsList() {
        if ($this->tags) {
            return array_filter( explode(',', $this->tags) );
        } else {
            return array_filter( explode(',', $this->artistsTags) );
        }
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

    private function cleanWord($word) {
        $word = mb_strtolower($word, 'utf-8');
        $word = trim($word);
        $word = str_replace(array("\"", "'", "(", ")"), "", $word); 
        return $word;
    }

    public function getCleanArtistsList() {
        $artists = array_filter( explode(',', $this->artists) );

        $ret = array();
        foreach ($artists as $a) {
            array_push($ret, $this->cleanWord($a)); 
        }

        return $ret;
    }
    /**
     * @var integer
     */
    private $catalogRate;


    /**
     * Set catalogRate
     *
     * @param integer $catalogRate
     * @return ActualInternalIndex
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
    /**
     * @var \DateTime
     */
    private $start;


    /**
     * Set start
     *
     * @param \DateTime $start
     * @return ActualInternalIndex
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

    public function getStartTimestamp()
    {
        return $this->start->getTimestamp();
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
     * @var string
     */
    private $tagsNames;


    /**
     * Set tagsNames
     *
     * @param string $tagsNames
     * @return ActualInternalIndex
     */
    public function setTagsNames($tagsNames)
    {
        $this->tagsNames = $tagsNames;

        return $this;
    }

    /**
     * Get tagsNames
     *
     * @return string 
     */
    public function getTagsNames()
    {
        return $this->tagsNames;
    }

    public function getTagsNamesList($count = null, $sym_count = null) {
        $tags = array_filter( explode(',', $this->tagsNames) );
        shuffle($tags);

        if ($sym_count && $sym_count > 0) {

            $done_flag = 0;
            $ret = array();
            $ret_len = 0;

            foreach ($tags as $t) {
                if (($ret_len + strlen($t)) < $sym_count) {
                    $ret_len += strlen($t);
                    array_push($ret, $t);
                }
            }

            return $ret;

        } else {
            if ($count) {
                return array_slice($tags, 0, $count);
            } else {
                return array_filter($tags);
            }
        }
    }

    /**
     * @var string
     */
    private $urlName;


    /**
     * Set urlName
     *
     * @param string $urlName
     * @return ActualInternalIndex
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

    public function getYear() {
        return $this->start->format('Y');
    }

    public function getMonth() {
        return $this->start->format('m');
    }

    public function getUrlId() {
        return $this->urlName ? $this->urlName : $this->internal_id;
    }
    /**
     * @var string
     */
    private $place;


    /**
     * Set place
     *
     * @param string $place
     * @return ActualInternalIndex
     */
    public function setPlace($place)
    {
        $this->place = $place;

        return $this;
    }

    /**
     * Get place
     *
     * @return string 
     */
    public function getPlace()
    {
        return $this->place;
    }
    /**
     * @var string
     */
    private $tickets;



    /**
     * Set tickets
     *
     * @param string $tickets
     * @return ActualInternalIndex
     */
    public function setTickets($tickets)
    {
        $this->tickets = $tickets;

        return $this;
    }

    /**
     * Get tickets
     *
     * @return string 
     */
    public function getTickets()
    {
        return $this->tickets;
    }

    public function getTicketsList() {
        if ($this->tickets) {
            $tickets = json_decode( $this->tickets, 1 );

            usort($tickets, function($a, $b) {
                if ($a['price_min'] == $b['price_min'])
                    return 0;

                return ($a['price_min'] < $b['price_min']) ? -1 : 1;
            });

            return $tickets;
        } else {
            return;
        }
    }

    private $weight;

    public function setWeight($weight) {
        $this->weight = $weight;

        return $this;
    }

    public function getWeight() {
        return $this->weight;
    }

    public function getPlaceInfo($what) {
        $place = json_decode( $this->getPlace(), 1 );
        return $place[$what];
    }

    public function howLong() {
        $now = new \DateTime;
        $dt  = $this->start;

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

    private function number($n, $titles) {
        $cases = array(2, 0, 1, 1, 1, 2);
        return $titles[($n % 100 > 4 && $n % 100 < 20) ? 2 : $cases[min($n % 10, 5)]];
    }

}
