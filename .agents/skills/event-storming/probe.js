// Evaluate in the rendered board. Done when every field is empty/false.
(() => {
  const clipped = (el) => el.scrollWidth > el.clientWidth + 1;
  const board = document.querySelector('.board');
  return {
    overflowingStickies: [...document.querySelectorAll('.sticky')]
      .filter((s) => clipped(s) || [...s.children].some(clipped))
      .map((s) => s.querySelector('p').textContent.slice(0, 40)),
    pageScrollsSideways: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    boardScrollsSideways: board.scrollWidth > board.clientWidth,
  };
})()
