// 开发阶段启用浏览器默认右键 + 文本复制/粘贴增强
// 注：生产可通过构建时移除或加环境判断

(function () {
  try {
    // 恢复默认 contextmenu（如果任何地方阻止）
    window.addEventListener('contextmenu', function (e) {
      // 放行默认菜单
    }, { capture: true });

    // 可选：为非输入元素快速复制其 data-copy 或 innerText（按住 Alt + 右键）
    window.addEventListener('contextmenu', function (e) {
      if (e.altKey) {
        const target = e.target;
        let text = '';
        if (target) {
          if (target.getAttribute && target.getAttribute('data-copy')) {
            text = target.getAttribute('data-copy');
          } else {
            text = (target.innerText || '').trim();
          }
        }
        if (text) {
          navigator.clipboard.writeText(text).then(() => {
            console.log('[DevCopy] Copied:', text.slice(0, 80));
          }).catch(err => console.warn('[DevCopy] Failed:', err));
        }
      }
    });

    console.log('[right_click_dev] 开发右键/复制增强脚本已加载');
  } catch (err) {
    console.warn('[right_click_dev] 初始化失败', err);
  }
})();

