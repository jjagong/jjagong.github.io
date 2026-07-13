---
title: phpMyRedis
tags:
  - Dreamhack
  - web
  - writeup
---
# 1. 문제
![[assets/Pasted image 20260713143306.png]]
- php로 redis를 관리하는 서비스에서 취약점을 찾고 flag를 획득하는 문제이다.
# 2. 문제 분석
- config.php 페이지에서 접근해 입력하게 되면 php에서 Redis config 확장 메서드를 사용해 요청 보낸다.
	- config.php 파일 코드
	  ```php
	  <?php
         if(isset($_POST['option'])){
           $redis = new Redis();
           $redis->connect($REDIS_HOST);
           if($_POST['option'] == 'GET'){
             $ret = json_encode($redis->config($_POST['option'], $_POST['key']));
           }elseif($_POST['option'] == 'SET'){
             $ret = $redis->config($_POST['option'], $_POST['key'], $_POST['value']);
           }else{
              die('error !');
           }                    
           echo '<h1 class="subtitle">Result</h1>';
           echo "<pre>$ret</pre>";
           }
     ?>
	  ```
- index.php 페이지에서는 Redis eval 확장 메서드를 사용해 입력 받은 cmd를 lua 스크립트로 보낸다.
```php
if(isset($_POST['cmd'])){
    $redis = new Redis();
    $redis->connect($REDIS_HOST);
    $ret = json_encode($redis->eval($_POST['cmd']));
```
# 3. 문제 풀이
1. config 페이지에서 GET 요청으로 dir을 보내 현재 저장 경로를 조회한다.
	![[Pasted image 20260713154414.png]]
	- 현재 저장 경로 `/var/www/html`
2. SET 요청을 통해 저장 위치를 변경한다.
	1. 