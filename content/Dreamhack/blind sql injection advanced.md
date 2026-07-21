---
title: blind sql injection advanced
tags:
  - Dreamhack
  - web
  - writeup
---
# 1. 문제
![[Pasted image 20260720220044.png]]
# 2. 문제 접근
- blind sql injection 문제이고, 아스키 코드와 한글로 구성되어 있기 때문에 한글은 11172개 아스키 코드는 128개 중 출력 가능한 95개 사용해 총 11,267개가 범위가 된다.
- 처음 문제에 접근했을 때 경우의 수가 많기 때문에 