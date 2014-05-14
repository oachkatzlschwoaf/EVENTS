<?php

namespace Event\GeneralBundle;

use Symfony\Component\HttpFoundation\Request;

class VkApi {

    private $app_id;
    private $settings;

    public function __construct($args) {
        $this->settings = $args;
    }

    private function calcSecureSig($query) {
        ksort($query);

        $sig = '';
        foreach ($query as $v => $k) {
            $sig .= "$v=$k"; 
        }

        $sig .= $this->getServerKey();

        return md5($sig);
    }

    private function getServerKey() {
        return $this->settings['server_key']; 
    }        

    private function getApiUrl() {
        return $this->settings['api_url']; 
    }        

    private function getAppId() {
        return $this->settings['app_id']; 
    }        

    private function request($method, $params) {
        if ($curl = curl_init()) {

            $url = $this->getApiUrl().'/'.$method.'?'.http_build_query($params);

            # Process API request
            curl_setopt($curl, CURLOPT_URL, $url);
            curl_setopt($curl,CURLOPT_RETURNTRANSFER,true);
            $out = curl_exec($curl);
            curl_close($curl);

            $data = json_decode($out);

            return $data;
        }
        
        return;
    }

    public function requestSecure($method, $params) {
        $params['app_id'] = $this->getAppId();

        $data = $this->request($method, $params);

        return $data;
    }

    public function getUserInfo($uid, $access_token) {
        $data = $this->requestSecure('users.get', array('access_token' => $access_token, 'user_ids' => $uid, 'fields' => 'sex,bdate,city,country,photo_max,photo_max_orig,domain,has_mobile,common_count,relation,counters,screen_name,timezone')); 

        if (isset($data->error)) {
            error_log( print_r($data, 1) );
            return; 
        } else {
            return $data->response[0];
        }
    }

    public function getAudio($uid, $access_token) {
        $data = $this->requestSecure('audio.get', array('access_token' => $access_token, 'count' => 6000)); 

        if (isset($data->error)) {
            error_log( print_r($data, 1) );
            return; 
        } else {
            return $data->response;
        }
    }
}
