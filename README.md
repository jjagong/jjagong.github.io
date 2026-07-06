# jjagong blog

Obsidian으로 글을 쓰고 Quartz로 빌드해서 GitHub Pages에 배포하는 블로그입니다.

## 어디에 글을 쓰면 되나

Obsidian에서 `C:\Users\jungb\jjagong_blog` 폴더를 vault로 열고, `content` 폴더 안에 Markdown 파일을 만들면 됩니다.

예시 경로:

- `content/index.md`
- `content/dev/first-note.md`
- `content/security/writeup.md`

## 로컬 미리보기

```powershell
npm ci
npx quartz build --serve
```

브라우저에서 `http://localhost:8080` 를 열면 됩니다.

## 배포

이 저장소는 GitHub Pages용 GitHub Actions 워크플로를 포함합니다.
`main` 브랜치에 push 하면 사이트가 배포되도록 설정했습니다.
