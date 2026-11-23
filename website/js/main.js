/* ==============================================================================
   MCons — Official Showcase Website Logic
   Interactions • Copy Handlers • Tab Switchers
   ============================================================================== */

document.addEventListener("DOMContentLoaded", () => {
  initHeroCopy();
  initAppShowcaseTabs();
  initCliTabs();
  initMacInstallCopy();
  initFaqAccordion();
});

/* ── 1. Hero Terminal Copy ───────────────────────────────────────────────── */
function initHeroCopy() {
  const btn = document.getElementById("heroCopyBtn");
  const label = document.getElementById("heroCopyLabel");
  const cmd = "curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash";

  if (btn && label) {
    btn.addEventListener("click", () => {
      navigator.clipboard.writeText(cmd).then(() => {
        label.textContent = "Copied";
        setTimeout(() => {
          label.textContent = "Copy";
        }, 2000);
      });
    });
  }
}

/* ── 2. App Showcase Screenshot Tabs ─────────────────────────────────────── */
function initAppShowcaseTabs() {
  const tabs = document.querySelectorAll(".f-tab");
  const mainImg = document.getElementById("mainAppScreen");
  const reelCells = document.querySelectorAll(".reel-cell");

  if (!mainImg) return;

  function switchImage(src, activeTab) {
    mainImg.style.opacity = "0.4";
    setTimeout(() => {
      mainImg.src = src;
      mainImg.style.opacity = "1";
    }, 120);

    if (activeTab) {
      tabs.forEach(t => t.classList.remove("active"));
      activeTab.classList.add("active");
    }
  }

  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      const shot = tab.dataset.shot;
      if (shot) switchImage(shot, tab);
    });
  });

  reelCells.forEach(cell => {
    cell.addEventListener("click", () => {
      const img = cell.querySelector("img");
      if (img && img.src) {
        const matchTab = Array.from(tabs).find(t => t.dataset.shot && img.src.includes(t.dataset.shot));
        switchImage(img.src, matchTab);
        document.querySelector(".hero-visual-frame")?.scrollIntoView({ behavior: "smooth", block: "center" });
      }
    });
  });
}

/* ── 3. CLI Terminal Tab Switching & Copy ────────────────────────────────── */
function initCliTabs() {
  const tabs = document.querySelectorAll(".cli-tab");
  const targetCode = document.getElementById("cliCommandTarget");
  const copyBtn = document.getElementById("cliCopyBtn");
  const copyText = document.getElementById("cliCopyText");

  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      tabs.forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
      const cmd = tab.dataset.cmd;
      if (targetCode && cmd) {
        targetCode.textContent = cmd;
      }
    });
  });

  if (copyBtn && targetCode && copyText) {
    copyBtn.addEventListener("click", () => {
      const text = targetCode.textContent.trim();
      navigator.clipboard.writeText(text).then(() => {
        copyText.textContent = "Copied";
        setTimeout(() => {
          copyText.textContent = "Copy";
        }, 2000);
      });
    });
  }
}

/* ── 4. Mac Install Card Copy ────────────────────────────────────────────── */
function initMacInstallCopy() {
  const btn = document.getElementById("copyMacBtn");
  const label = document.getElementById("copyMacText");
  const cmd = "curl -fsSL https://raw.githubusercontent.com/neel0210/MCons/main/install.sh | bash";

  if (btn && label) {
    btn.addEventListener("click", () => {
      navigator.clipboard.writeText(cmd).then(() => {
        label.textContent = "Copied to Clipboard";
        setTimeout(() => {
          label.textContent = "Copy Terminal Command";
        }, 2000);
      });
    });
  }
}

/* ── 5. FAQ Accordion ────────────────────────────────────────────────────── */
function initFaqAccordion() {
  const rows = document.querySelectorAll(".faq-row");
  rows.forEach(row => {
    const trigger = row.querySelector(".faq-trigger");
    trigger?.addEventListener("click", () => {
      const wasActive = row.classList.contains("active");
      rows.forEach(r => r.classList.remove("active"));
      if (!wasActive) {
        row.classList.add("active");
      }
    });
  });
}
