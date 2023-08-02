import Prism from "prismjs";

Prism.languages.formula = {
  operator: /([=!><]=)|&&|[*\/+><^!]/,
  number: /-?\b\d+(?:\.\d+)?(?:e[+-]?\d+)?\b/i,
  boolean: /\b(?:false|true)\b/,
  punctuation: /[()[\]]/,
  function: /\b(?:sin|cos|tan|round|ceil|floor)\b/,
  null: {
    pattern: /\bnull\b/,
    alias: "keyword",
  },
};

function customizeLanguage(variables) {
  const changes = {};

  if (variables.length > 0) {
    const varsString = variables.join("|");

    changes.variable = new RegExp(`\\b(${varsString})\\b`);
  }

  return {
    ...changes,
    ...Prism.languages.formula,
  };
}

export const InputHook = {
  mounted() {
    this.el.addEventListener("input", () => {
      this.position = getCaretPosition(this.el);
      updateInputValue(this);
    });

    this.el.parentElement
      .querySelectorAll("[data-equation-symbol]")
      .forEach((item) =>
        item.addEventListener("click", () => {
          this.position = getCaretPosition(this.el);
          insertSymbol(this, item.dataset.equationSymbol);
          updateInputValue(this);
        })
      );

    updateContent(this, true);
  },
  updated() {
    updateContent(this, true);
  },
};

export const ContentHook = {
  mounted() {
    updateContent(this);
  },
  updated() {
    updateContent(this);
  },
};

function insertSymbol(hook, symbol) {
  const contentEl = hook.el;

  const value = contentEl.textContent + symbol;

  formatContent(contentEl, value);

  setCaretPosition(contentEl, hook.position);
}

function updateContent(hook, readInput = false) {
  let value;
  const contentEl = hook.el;

  if (readInput) {
    const input = document.getElementById(contentEl.dataset.targetInput);
    value = input.value;
  } else {
    value = contentEl.textContent;
  }

  formatContent(contentEl, value);

  if (hook.position) {
    setCaretPosition(contentEl, hook.position);
  }
}

function updateInputValue(hook, append = "") {
  const input = document.getElementById(hook.el.dataset.targetInput);
  input.value = hook.el.textContent + append;
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

function formatContent(contentEl, value) {
  const vars = contentEl.dataset.variables?.split(",") || [];

  const language = customizeLanguage(vars);

  contentEl.innerHTML = Prism.highlight(value, language, "formula");
}

function getCaretPosition(containerEl) {
  const range = window.getSelection().getRangeAt(0);
  const preSelectionRange = range.cloneRange();
  preSelectionRange.selectNodeContents(containerEl);
  preSelectionRange.setEnd(range.startContainer, range.startOffset);
  const start = preSelectionRange.toString().length;

  return {
    start: start,
    end: start + range.toString().length,
  };
}

function setCaretPosition(containerEl, selection) {
  const range = document.createRange();
  const nodeStack = [containerEl];

  let node,
    charIndex = 0,
    foundStart = false,
    stop = false;

  range.setStart(containerEl, 0);
  range.collapse(true);

  while (!stop && (node = nodeStack.pop())) {
    if (node.nodeType == 3) {
      let nextCharIndex = charIndex + node.length;
      if (
        !foundStart &&
        selection.start >= charIndex &&
        selection.start <= nextCharIndex
      ) {
        range.setStart(node, selection.start - charIndex);
        foundStart = true;
      }
      if (
        foundStart &&
        selection.end >= charIndex &&
        selection.end <= nextCharIndex
      ) {
        range.setEnd(node, selection.end - charIndex);
        stop = true;
      }
      charIndex = nextCharIndex;
    } else {
      let i = node.childNodes.length;
      while (i--) {
        nodeStack.push(node.childNodes[i]);
      }
    }
  }

  var sel = window.getSelection();
  sel.removeAllRanges();
  sel.addRange(range);
}
