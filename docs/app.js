// MCons Landing Page Interactive Logic

document.addEventListener('DOMContentLoaded', () => {
  initLiveMockup();
  initPacksExplorer();
  initBrewCopy();
  initModal();
  initReleaseLinks();
  initInstallerModal();
});

// 1. Live macOS Window Mockup Interactive Demo
function initLiveMockup() {
  const folderSvg = document.getElementById('mockupFolderSvg');
  const overlayIcon = document.getElementById('mockupOverlayIcon');
  const targetName = document.getElementById('mockupTargetName');
  const iconChips = document.querySelectorAll('.icon-chip-btn');
  const colorSwatches = document.querySelectorAll('.swatch-btn');
  const segButtons = document.querySelectorAll('.seg-btn');
  const applyBtn = document.getElementById('mockupApplyBtn');

  // Interactive Icon selector
  iconChips.forEach(chip => {
    chip.addEventListener('click', () => {
      iconChips.forEach(c => c.classList.remove('active'));
      chip.classList.add('active');

      const iconSrc = chip.getAttribute('data-icon');
      const iconName = chip.getAttribute('data-name');
      
      if (overlayIcon) {
        overlayIcon.src = iconSrc;
      }
      if (targetName && iconName) {
        targetName.textContent = `${iconName} Projects`;
      }
    });
  });

  // Interactive Color Swatch Tinting
  colorSwatches.forEach(swatch => {
    swatch.addEventListener('click', () => {
      colorSwatches.forEach(s => s.classList.remove('active'));
      swatch.classList.add('active');

      const color = swatch.getAttribute('data-color');
      const folderFront = document.getElementById('folderFrontPath');
      const folderTab = document.getElementById('folderTabPath');

      if (folderFront) {
        folderFront.setAttribute('fill', color);
      }
      if (folderTab) {
        folderTab.setAttribute('fill', color);
      }
    });
  });

  // Segment Buttons (Single / Batch / Builder)
  segButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      segButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
    });
  });

  // Apply button simulated feedback
  if (applyBtn) {
    applyBtn.addEventListener('click', () => {
      const originalText = applyBtn.textContent;
      applyBtn.textContent = '✓ Applied to Finder!';
      applyBtn.style.background = '#10b981';
      showToast('Icon applied! Check Finder & Desktop.');
      setTimeout(() => {
        applyBtn.textContent = originalText;
        applyBtn.style.background = '';
      }, 2000);
    });
  }
}

// 2. Icon Packs Explorer Grid & Filter
function initPacksExplorer() {
  const packsGrid = document.getElementById('packsGrid');
  const searchInput = document.getElementById('packSearchInput');
  const catButtons = document.querySelectorAll('.cat-btn');

  if (!packsGrid || typeof MCONS_PACKS === 'undefined') return;

  let currentCategory = 'all';
  let searchQuery = '';

  function render() {
    packsGrid.innerHTML = '';

    const filtered = MCONS_PACKS.filter(pack => {
      const matchesCat = currentCategory === 'all' || 
        (pack.category && pack.category.toLowerCase().includes(currentCategory.toLowerCase()));
      
      const query = searchQuery.toLowerCase().trim();
      const matchesSearch = !query || 
        pack.name.toLowerCase().includes(query) ||
        pack.id.toLowerCase().includes(query) ||
        (pack.description && pack.description.toLowerCase().includes(query)) ||
        (pack.icons && pack.icons.some(i => i.name.toLowerCase().includes(query)));

      return matchesCat && matchesSearch;
    });

    if (filtered.length === 0) {
      packsGrid.innerHTML = `
        <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-tertiary);">
          <p style="font-size: 1.1rem; margin-bottom: 8px;">No icon packs found matching "${searchQuery}"</p>
          <p style="font-size: 0.85rem;">Try searching for "anime", "docker", "naruto", or "camera".</p>
        </div>
      `;
      return;
    }

    filtered.forEach(pack => {
      const card = document.createElement('div');
      card.className = 'pack-card';
      card.onclick = () => openPackModal(pack);

      const previewHtml = (pack.previews && pack.previews.length > 0) 
        ? pack.previews.slice(0, 3).map(p => `
            <div class="pack-preview-item" title="${pack.name}">
              <img src="assets/preview-icons/${p}" alt="icon" loading="lazy" />
            </div>
          `).join('')
        : `<div class="pack-preview-item"><img src="assets/icon-256.png" alt="pack" /></div>`;

      card.innerHTML = `
        <div class="pack-header">
          <span class="pack-name">${pack.name}</span>
          <span class="pack-badge">${pack.count || pack.icons.length} Icons</span>
        </div>
        <p class="pack-desc">${pack.description || 'Vector icon pack optimized for macOS folder styling.'}</p>
        <div class="pack-previews">
          ${previewHtml}
          <span class="pack-view-more">View all →</span>
        </div>
      `;
      packsGrid.appendChild(card);
    });
  }

  // Category tab clicks
  catButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      catButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentCategory = btn.getAttribute('data-cat') || 'all';
      render();
    });
  });

  // Search input typing
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value;
      render();
    });
  }

  render();
}

// 3. Modal Popup for viewing full pack icons
function initModal() {
  const overlay = document.getElementById('packModal');
  const closeBtn = document.getElementById('modalCloseBtn');

  if (closeBtn && overlay) {
    closeBtn.addEventListener('click', () => {
      overlay.classList.remove('active');
    });
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) {
        overlay.classList.remove('active');
      }
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && overlay.classList.contains('active')) {
        overlay.classList.remove('active');
      }
    });
  }
}

function openPackModal(pack) {
  const overlay = document.getElementById('packModal');
  const title = document.getElementById('modalTitle');
  const desc = document.getElementById('modalDesc');
  const count = document.getElementById('modalCount');
  const grid = document.getElementById('modalIconsGrid');

  if (!overlay || !grid) return;

  title.textContent = pack.name;
  desc.textContent = pack.description || '';
  count.textContent = `${pack.count || pack.icons.length} Vector Icons`;

  grid.innerHTML = '';
  const icons = pack.icons || [];
  icons.forEach(icon => {
    const item = document.createElement('div');
    item.className = 'modal-icon-card';
    item.innerHTML = `
      <div style="font-weight:600; margin-top:4px;">${icon.name}</div>
      <div style="color:var(--text-tertiary); font-size:0.7rem;">${icon.category || pack.category || 'Vector'}</div>
    `;
    grid.appendChild(item);
  });

  overlay.classList.add('active');
}

// 4. Brew Copy button & Toast
function initBrewCopy() {
  const brewBox = document.getElementById('brewCopyBox');
  if (brewBox) {
    brewBox.addEventListener('click', () => {
      const code = 'brew install --cask mcons';
      navigator.clipboard.writeText(code).then(() => {
        showToast('Copied "brew install --cask mcons" to clipboard!');
      }).catch(() => {
        showToast('Command: brew install --cask mcons');
      });
    });
  }
}

function showToast(msg) {
  let toast = document.getElementById('toastMsg');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'toastMsg';
    toast.className = 'toast-msg';
    document.body.appendChild(toast);
  }
  toast.textContent = msg;
  toast.classList.add('show');
  setTimeout(() => {
    toast.classList.remove('show');
  }, 2500);
}

// 5. Dynamic Release Asset Resolution
function initReleaseLinks() {
  fetch('https://api.github.com/repos/neel0210/MCons/releases/latest')
    .then(r => r.json())
    .then(data => {
      const dmg = data.assets && data.assets.find(a => a.name.endsWith('.dmg'));
      if (dmg) {
        const heroBtn = document.getElementById('heroDmgBtn');
        const mainBtn = document.getElementById('mainDmgBtn');
        const filename = dmg.name || 'MCons.dmg';
        const downloadUrl = `https://github.com/neel0210/MCons/releases/latest/download/${filename}`;
        if (heroBtn) {
          heroBtn.href = downloadUrl;
          heroBtn.setAttribute('download', filename);
        }
        if (mainBtn) {
          mainBtn.href = downloadUrl;
          mainBtn.setAttribute('download', filename);
        }
      }
    })
    .catch(() => {});
}

// 6. Interactive macOS Installer Instructions Modal
function initInstallerModal() {
  const modal = document.getElementById('installerModal');
  const closeBtn = document.getElementById('installerModalCloseBtn');
  const gotItBtn = document.getElementById('installerGotItBtn');
  const heroBtn = document.getElementById('heroDmgBtn');
  const mainBtn = document.getElementById('mainDmgBtn');
  const cmdBox = document.getElementById('cmdCopyBox');

  const openModal = () => {
    if (modal) {
      setTimeout(() => {
        modal.classList.add('active');
      }, 250);
    }
  };

  const closeModal = () => {
    if (modal) {
      modal.classList.remove('active');
    }
  };

  if (heroBtn) {
    heroBtn.addEventListener('click', openModal);
  }
  if (mainBtn) {
    mainBtn.addEventListener('click', openModal);
  }

  if (closeBtn) {
    closeBtn.addEventListener('click', closeModal);
  }
  if (gotItBtn) {
    gotItBtn.addEventListener('click', closeModal);
  }

  if (modal) {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        closeModal();
      }
    });
  }

  if (cmdBox) {
    cmdBox.addEventListener('click', () => {
      const cmd = 'xattr -cr /Applications/MCons.app';
      navigator.clipboard.writeText(cmd).then(() => {
        showToast('Copied "xattr -cr /Applications/MCons.app" to clipboard!');
      }).catch(() => {
        showToast('Command: xattr -cr /Applications/MCons.app');
      });
    });
  }
}


