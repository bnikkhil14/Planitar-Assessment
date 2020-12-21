window.onload = () => {
   const revealBtn = document.getElementById('reveal');
   revealBtn.disabled = false;
   revealBtn.onclick = () => {
      document.getElementById('answer').innerHTML = '4';
      document.getElementById('question').classList.add('answered');
   };
};
