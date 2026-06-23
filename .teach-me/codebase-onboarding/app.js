(() => {
  const data = window.TEACH_ME_COURSE;
  const app = document.getElementById("app");
  if (!data) {
    app.innerHTML = "<main class='stage'><h1>Missing course-data.js</h1><p>Run publish-viewer.py for this course.</p></main>";
    return;
  }

  const plan = data.plan || {};
  const course = plan.course || {};
  const lessons = (data.lessons && data.lessons.lessons) || [];
  const slug = (data.courseDir || course.title || "course").split(/[\\/]/).filter(Boolean).pop();
  const storageKey = `teach-me:${slug}:progress:v1`;
  const state = loadState();
  let lessonIndex = state.currentLessonIndex || 0;
  let beatIndex = state.currentBeatIndex || 0;
  let selected = {};

  function loadState() {
    try {
      return JSON.parse(localStorage.getItem(storageKey)) || {};
    } catch { return {}; }
  }
  function saveState() {
    state.currentLessonIndex = lessonIndex;
    state.currentBeatIndex = beatIndex;
    localStorage.setItem(storageKey, JSON.stringify(state));
  }
  function lesson() { return lessons[lessonIndex] || { beats: [] }; }
  function beat() { return (lesson().beats || [])[beatIndex] || {}; }
  function beatKey(li = lessonIndex, bi = beatIndex) {
    const l = lessons[li];
    const b = l && l.beats && l.beats[bi];
    return `${l ? l.id : li}/${b ? b.id : bi}`;
  }
  function completedSet() { return new Set(state.completedBeats || []); }
  function isCurrentBeatComplete() { return completedSet().has(beatKey()); }
  function refreshDoneButton() {
    const btn = document.querySelector('[data-action="done"]');
    if (!btn) return;
    const done = isCurrentBeatComplete();
    btn.classList.toggle("done-state", done);
    btn.textContent = done ? "Done ✓" : "I did this";
  }
  function markComplete() {
    const set = completedSet();
    set.add(beatKey());
    state.completedBeats = [...set];
    saveState();
    refreshDoneButton();
  }
  function unmarkComplete() {
    const set = completedSet();
    set.delete(beatKey());
    state.completedBeats = [...set];
    saveState();
    refreshDoneButton();
  }
  function toggleComplete() {
    if (isCurrentBeatComplete()) unmarkComplete();
    else markComplete();
  }
  function escape(s) {
    return String(s || "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[c]));
  }
  function inline(s) {
    const text = String(s || "");
    const parts = text.split(/(`[^`]*`)/g);
    return parts.map(part => {
      if (part.startsWith("`") && part.endsWith("`") && part.length >= 2) {
        return `<code>${escape(part.slice(1, -1))}</code>`;
      }
      return escape(part);
    }).join("");
  }
  function promptBlock(text) {
    return `<div class="prompt-card"><div class="prompt-text">${inline(text)}</div></div>`;
  }
  function para(text) {
    return `<p>${inline(text)}</p>`;
  }
  let mermaidReady = false;
  function initMermaid() {
    if (!window.mermaid || mermaidReady) return;
    window.mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: "base" });
    mermaidReady = true;
  }
  async function renderMermaidDiagrams() {
    initMermaid();
    if (!window.mermaid) return;
    try {
      await window.mermaid.run({ querySelector: ".mermaid" });
    } catch (error) {
      console.error("Mermaid render failed", error);
    }
  }
  function diagramBlock(d) {
    const syntax = (d.syntax || "mermaid").toLowerCase();
    const code = String(d.code || "").trim();
    if (syntax !== "mermaid") {
      return `<div class="card"><p>Unsupported diagram syntax: ${escape(syntax)}</p></div>`;
    }
    return `<div class="diagram-card"><pre class="mermaid">${escape(code)}</pre></div>${d.caption ? para(d.caption) : ""}`;
  }
  function renderDiagram(b) {
    return `<h2>${inline(b.title || "Diagram")}</h2>${diagramBlock(b)}`;
  }
  function attachedDiagram(b) {
    if (!b.diagram) return "";
    const title = b.diagram.title ? `<h3>${inline(b.diagram.title)}</h3>` : "";
    return `${title}${diagramBlock(b.diagram)}`;
  }
  function labelForReference(name) {
    return String(name || "")
      .replace(/\.md$/i, "")
      .split(/[-_]/)
      .filter(Boolean)
      .map(part => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ");
  }
  function renderReferenceLinks() {
    const entries = Object.entries(data.reference || {}).filter(([, value]) => value);
    if (!entries.length) return `<span class="muted">No reference files found.</span>`;
    return entries.map(([name]) => `<a href="./reference/${encodeURIComponent(name)}" target="_blank" rel="noopener">${escape(labelForReference(name))}</a>`).join("");
  }
  async function copy(text) {
    await navigator.clipboard.writeText(text);
    toast("Copied");
  }
  function toast(msg) {
    const el = document.querySelector(".toast");
    el.textContent = msg;
    el.classList.add("show");
    setTimeout(() => el.classList.remove("show"), 1300);
  }
  function totalBeats() { return lessons.reduce((sum, l) => sum + (l.beats || []).length, 0); }
  function lessonBeatCount(l = lesson()) { return (l.beats || []).length; }
  function completedBeatCountForLesson(l = lesson()) {
    const set = completedSet();
    return (l.beats || []).filter(b => set.has(`${l.id}/${b.id}`)).length;
  }
  function completedLessons() {
    const set = completedSet();
    return lessons.map(l => (l.beats || []).every(b => set.has(`${l.id}/${b.id}`)));
  }
  function progressMeter(label, done, total, tone = "") {
    const percent = Math.round((done / Math.max(total, 1)) * 100);
    return `<div class="progress-meter ${tone}"><div class="progress-label"><span>${escape(label)}</span><span>${done}/${total} · ${percent}%</span></div><div class="progress"><div style="width:${Math.max(2, percent)}%"></div></div></div>`;
  }
  function progressPayload(extraNote = "") {
    return {
      courseSlug: slug,
      courseTitle: course.title,
      currentLessonId: lesson().id,
      currentBeatId: beat().id,
      completedBeats: state.completedBeats || [],
      answers: state.answers || {},
      noteForPi: extraNote,
      copiedAt: new Date().toISOString()
    };
  }

  function render() {
    if (!lessons.length) {
      app.innerHTML = "<main class='stage'><h1>No lessons found</h1><p>lessons.json is empty or invalid.</p></main>";
      return;
    }
    const b = beat();
    const total = totalBeats();
    const done = completedSet().size;
    const lessonTotal = lessonBeatCount();
    const lessonDone = completedBeatCountForLesson();
    const currentBeatDone = isCurrentBeatComplete();
    app.innerHTML = `
      <div class="layout">
        <aside class="sidebar">
          <div class="brand">
            <h1>${escape(course.title || "Teach Me")}</h1>
            <p>${escape(course.mission || course.topic || "")}</p>
          </div>
          <div class="lesson-list">${lessons.map((l, i) => `
            <button class="lesson-link ${i === lessonIndex ? "active" : ""} ${completedLessons()[i] ? "done" : ""}" data-lesson="${i}">
              <span class="lesson-title">${escape(l.title)}</span>
              <span class="lesson-meta">${(l.beats || []).length} beats</span>
            </button>`).join("")}</div>
        </aside>
        <main class="stage">
          <div class="topbar">
            <details class="top-menu">
              <summary>Reference</summary>
              <div class="menu-panel link-list">${renderReferenceLinks()}</div>
            </details>
            <details class="top-menu pi-menu">
              <summary>Talk to Pi</summary>
              <div class="menu-panel pi-panel">
                <small>Write a question or feedback, then copy it into your Pi window. Pi can revise the JSON and you refresh this viewer.</small>
                <textarea id="note" placeholder="Example: Lesson 3 onward feels too basic. Make the rest more senior and add harder practice."></textarea>
                <div class="menu-actions"><button class="primary" data-action="copy-note">Copy note + progress for Pi</button><button data-action="copy-progress">Copy progress only</button></div>
              </div>
            </details>
          </div>
          <div class="progress-stack">
            ${progressMeter("This lesson", lessonDone, lessonTotal, "lesson-progress")}
            ${progressMeter("Whole course", done, total, "course-progress")}
          </div>
          <section class="beat">
            <div class="kicker">${escape(lesson().title)} · Beat ${beatIndex + 1}/${(lesson().beats || []).length} · ${escape(b.type)}</div>
            ${renderBeat(b)}
          </section>
          <nav class="nav">
            <div class="left"><button class="ghost" data-action="prev">← Back</button></div>
            <div class="right"><button class="${currentBeatDone ? "done-state" : ""}" data-action="done">${currentBeatDone ? "Done ✓" : "I did this"}</button><button class="primary" data-action="next">Next →</button></div>
          </nav>
        </main>
      </div>
      <div class="toast"></div>
    `;
    bind();
    renderMermaidDiagrams();
  }

  function renderBeat(b) {
    if (b.type === "explain") return `<h2>${inline(b.title || "Notice this")}</h2>${para(b.text)}${attachedDiagram(b)}`;
    if (b.type === "single-choice" || b.type === "multi-choice") {
      const key = beatKey();
      const picked = selected[key] || [];
      return `<h2>${b.type === "single-choice" ? "Question" : "Choose all that apply"}</h2>${promptBlock(b.prompt)}${attachedDiagram(b)}<div class="choices">${(b.choices || []).map(c => `<button class="choice ${picked.includes(c.id) ? "selected" : ""}" data-choice="${escape(c.id)}">${inline(c.text)}</button>`).join("")}</div><div id="feedback"></div><button data-action="check-choice">Check answer</button>`;
    }
    if (b.type === "prediction") return `<h2>Prediction</h2>${promptBlock(b.prompt)}${attachedDiagram(b)}<div class="card"><button data-action="reveal">Reveal answer</button><div id="reveal" hidden><h3>Expected</h3>${para(b.answer)}${b.explanation ? para(b.explanation) : ""}</div></div>`;
    if (b.type === "practice") return `<h2>Practice</h2>${promptBlock(b.instruction)}${attachedDiagram(b)}${b.copyText ? `<pre class="codebox">${escape(b.copyText)}</pre><button data-copy-text="${escape(b.copyText)}">Copy</button>` : ""}<div class="card"><strong>Signs of success</strong>${para(b.signsOfSuccess)}${b.hints ? `<details><summary>Hints</summary><p>${inline(Array.isArray(b.hints) ? b.hints.join("\n") : b.hints)}</p></details>` : ""}</div>`;
    if (b.type === "diagram") return renderDiagram(b);
    if (b.type === "checkpoint") return `<h2>Checkpoint</h2>${para(b.recap)}<div class="card">${para(b.readyPrompt || "Do you feel ready to continue?")}</div>`;
    return `<h2>${inline(b.type || "Beat")}</h2><pre>${escape(JSON.stringify(b, null, 2))}</pre>`;
  }

  function bind() {
    document.querySelectorAll("[data-lesson]").forEach(btn => btn.addEventListener("click", () => { lessonIndex = Number(btn.dataset.lesson); beatIndex = 0; saveState(); render(); }));
    document.querySelectorAll("[data-action]").forEach(btn => btn.addEventListener("click", () => action(btn.dataset.action)));
    document.querySelectorAll("[data-choice]").forEach(btn => btn.addEventListener("click", () => {
      const key = beatKey();
      const b = beat();
      selected[key] = selected[key] || [];
      if (b.type === "single-choice") selected[key] = [btn.dataset.choice];
      else selected[key] = selected[key].includes(btn.dataset.choice) ? selected[key].filter(x => x !== btn.dataset.choice) : [...selected[key], btn.dataset.choice];
      render();
    }));
    document.querySelectorAll("[data-copy-text]").forEach(btn => btn.addEventListener("click", () => copy(btn.dataset.copyText)));
  }

  function action(name) {
    if (name === "prev") { if (beatIndex > 0) beatIndex--; else if (lessonIndex > 0) { lessonIndex--; beatIndex = (lessons[lessonIndex].beats || []).length - 1; } saveState(); render(); }
    if (name === "next") { markComplete(); if (beatIndex < (lesson().beats || []).length - 1) beatIndex++; else if (lessonIndex < lessons.length - 1) { lessonIndex++; beatIndex = 0; } saveState(); render(); }
    if (name === "done") { toggleComplete(); render(); }
    if (name === "reveal") { document.getElementById("reveal").hidden = false; markComplete(); }
    if (name === "check-choice") checkChoice();
    if (name === "copy-progress") copy(JSON.stringify(progressPayload(), null, 2));
    if (name === "copy-note") copy(JSON.stringify(progressPayload(document.getElementById("note").value), null, 2));
  }

  function checkChoice() {
    const b = beat();
    const picked = selected[beatKey()] || [];
    const correct = (b.choices || []).filter(c => c.correct).map(c => c.id).sort().join(",");
    const got = [...picked].sort().join(",");
    const ok = correct === got;
    state.answers = state.answers || {};
    state.answers[beatKey()] = { picked, ok, at: new Date().toISOString() };
    if (ok) markComplete(); else saveState();
    const el = document.getElementById("feedback");
    el.className = `feedback ${ok ? "good" : "bad"}`;
    el.textContent = ok ? (b.feedback && b.feedback.correct) || "Correct." : (b.feedback && b.feedback.incorrect) || "Not quite. Try again or ask Pi why.";
  }

  render();
})();
