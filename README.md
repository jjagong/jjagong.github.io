# jjagong blog

Obsidian으로 글을 쓰고 Quartz로 빌드해서 GitHub Pages에 배포하는 블로그입니다.

## 어디에 글을 쓰면 되나

Obsidian에서는 `C:\Users\jungb\jjagong_blog\content` 폴더만 vault로 여는 것을 추천합니다.

루트 폴더인 `C:\Users\jungb\jjagong_blog` 전체를 vault로 열면 `quartz`, `node_modules`, 각종 `README.md` 파일까지 그래프에 잡혀서 매우 지저분해집니다.

즉:

- Obsidian에서 열 폴더: `C:\Users\jungb\jjagong_blog\content`
- Git/터미널/배포 작업을 하는 프로젝트 루트: `C:\Users\jungb\jjagong_blog`

`content` 폴더 안에 Markdown 파일을 만들면 됩니다.

예시 경로:

- `content/index.md`
- `content/dev/first-note.md`
- `content/security/writeup.md`

## 로컬 미리보기

```powershell
npm ci
npx quartz build --serve
```

위 명령은 프로젝트 루트인 `C:\Users\jungb\jjagong_blog` 에서 실행하면 됩니다.

브라우저에서 `http://localhost:8080` 를 열면 됩니다.

## 배포

이 저장소는 GitHub Pages용 GitHub Actions 워크플로를 포함합니다.
`main` 브랜치에 push 하면 사이트가 배포되도록 설정했습니다.

## GitHub에 안 올리는 로컬 파일

아래 항목은 로컬 전용으로 유지되도록 ignore 되어 있습니다.

- 모든 `.obsidian/` 폴더
- Obsidian 휴지통 폴더 `.trash/`
- 캐시/빌드 산출물

즉 Obsidian 플러그인, 테마, 개인 레이아웃 설정은 로컬에서만 사용하고 GitHub에는 올라가지 않게 구성했습니다.
