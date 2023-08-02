import "./main.js";
import * as FormulaInput from "./hooks/formula_input";

let Hooks = {
  FormulaInput: FormulaInput.InputHook,
  FormulaContent: FormulaInput.ContentHook,
};

Hooks.TimeZoneHook = {
  mounted() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    this.pushEvent("client_timezone", { tz });
  },
};

Hooks.scrollToTop = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      window.scrollTo(0, 0);
    });
  },
};

Hooks.ProgressMeter = {
  mounted() {
    this.initProgressMeter();
  },
  updated() {
    this.initProgressMeter();
  },
  destroyed() {
    clearInterval(this.meterIntervals[this.el.id]);
  },
  initProgressMeter() {
    const markerTimes = updateMeterMarkers(this.el);
    updateMeterProgress(this.el, markerTimes);

    const id = this.el.id;
    if (this.meterIntervals[id]) clearInterval(this.meterIntervals[id]);
    if (isMeterActive(this.el))
      this.meterIntervals[id] = setInterval(
        () => updateMeterProgress(this.el, markerTimes),
        3000
      );
  },
  meterIntervals: {},
};

function updateMeterMarkers(rootEl) {
  const markers = rootEl.querySelectorAll("[data-progress-meter-marker]");
  const startTime = new Date(rootEl.dataset.progressMeterStart);
  const endTime = new Date(rootEl.dataset.progressMeterEnd);
  let markerTimes = [];

  for (const marker of markers) {
    const key = marker.dataset.progressMeterMarker;
    const time = new Date(marker.dataset.progressMeterMarkerTime);
    const isDynamic =
      typeof marker.dataset.progressMeterMarkerDynamic !== "undefined";
    const isActiveOnly =
      typeof marker.dataset.progressMeterMarkerActiveOnly !== "undefined";
    const progress = calculateProgress(time, startTime, endTime);

    markerTimes.push({ key, time, isActiveOnly, isDynamic });

    marker.style.left = progressToCSS(progress, isDynamic);
  }

  return markerTimes
    .sort((a, b) => b.time - a.time)
    .map((marker, index, markers) => {
      if (index === 0) return { ...marker, endTime };

      const prevMarker = markers[index - 1];
      return { ...marker, endTime: prevMarker.time };
    }, null);
}

function isMeterActive(rootEl) {
  const meter = rootEl.querySelector("[data-progress-meter]");

  return !meter.dataset.progressMeter;
}

function updateMeterProgress(rootEl, markerTimes) {
  const meter = rootEl.querySelector("[data-progress-meter]");

  const completedTime = meter.dataset.progressMeter;
  const startTime = new Date(rootEl.dataset.progressMeterStart);
  const endTime = new Date(rootEl.dataset.progressMeterEnd);
  const meterTime = completedTime ? new Date(completedTime) : new Date();

  markerTimes = markerTimes.filter(
    ({ isActiveOnly, isDynamic }) =>
      !(isDynamic || (isActiveOnly && !!completedTime))
  );

  const activeMarker =
    markerTimes.find(({ time }) => meterTime >= time) ||
    markerTimes[markerTimes.length - 1];

  updateTargetMarkerClass(rootEl, activeMarker, markerTimes);
  updateMeterLabel(rootEl, meterTime, activeMarker);

  const meterProgress = calculateProgress(meterTime, startTime, endTime);
  meter.style.width = progressToCSS(meterProgress);
}

function updateMeterLabel(rootEl, meterTime, activeMarker) {
  const { time, endTime } = activeMarker;
  const meterLabels = rootEl.querySelectorAll("[data-progress-meter-label]");

  for (const meterLabel of meterLabels) {
    if (meterLabel.dataset.progressMeterLabel === activeMarker.key) {
      let spent;
      switch (meterLabel.dataset.progressMeterLabelType) {
        case "time_remaining":
          spent = meterTime - time;
          const duration = endTime - time;

          meterLabel.textContent = `${displayMinutes(
            spent
          )} of ${displayMinutes(duration)}`;
          break;
        case "time_past":
          spent = meterTime - time;

          meterLabel.textContent = `${displayMinutes(spent)} behind`;
          break;
      }
      meterLabel.style.display = "block";
    } else {
      meterLabel.style.display = "none";
    }
  }
}

function displayMinutes(milliseconds) {
  const totalMinutes = Math.round(milliseconds / 60 / 1000);
  const minutes = new String(totalMinutes % 60);
  const hours = Math.floor(totalMinutes / 60);

  console.log(totalMinutes);

  if (hours > 0) return `${hours}:${minutes.padStart(2, "0")} hrs`;

  return `${minutes} mins`;
}

function updateTargetMarkerClass(rootEl, activeMarker, markerTimes) {
  const markerClassTargets = rootEl.querySelectorAll(
    "[data-progress-meter-marker-class]"
  );

  const markerKeys = markerTimes.map(({ key }) => key);

  for (const markerClassTarget of markerClassTargets) {
    const baseClassName = markerClassTarget.dataset.progressMeterMarkerClass;

    for (const key of markerKeys) {
      if (key === activeMarker.key) {
        markerClassTarget.classList.add(baseClassName + key);
      } else {
        markerClassTarget.classList.remove(baseClassName + key);
      }
    }
  }
}

function progressToCSS(progress, isDynamic) {
  const percent = Math.round(progress * 10000) / 100;

  if (isDynamic) {
    if (progress > 1) return "calc(100% + 8px)";
    if (progress < 0) return "-8px";
    if (progress >= 0.75) return `min(calc(100% - 8px), ${percent}%)`;
    if (progress <= 0.25) return `max(8px, ${percent}%)`;
  } else {
    if (progress < 0) return "0";
    if (progress > 1) return "100%";
  }

  return percent + "%";
}

function calculateProgress(current, from, to) {
  const duration = to - from;
  const progressFrom = current - from;
  const percentage = progressFrom / duration;

  return percentage;
}

Hooks.DateRangePicker = {
  mounted() {
    const hook = this;
    $("#daterange").on("apply.daterangepicker", function (ev, picker) {
      $("#daterange").val(
        `${picker.startDate.format("L")} - ${picker.endDate.format("L")}`
      );
      hook.pushEvent("filter_by_dates", {
        start_date: picker.startDate.toISOString(),
        end_date: picker.endDate.toISOString(),
        displayed_date_range: $("#daterange").val(),
      });
    });
    $("#daterange").on("cancel.daterangepicker", function (ev, picker) {
      picker.setStartDate(moment());
      picker.setEndDate(moment());
      $("#daterange").val("");
      hook.pushEvent("filter_by_dates", {
        start_date: null,
        end_date: null,
        displayed_date_range: null,
      });
    });
  },
};

Hooks.HTMLInput = {
  mounted() {
    const target_input = document.getElementById(this.el.dataset.targetInput);

    InlineEditor.create(this.el, {
      toolbar: {
        items: [
          "heading",
          "|",
          "bold",
          "italic",
          "blockQuote",
          "link",
          "|",
          "indent",
          "outdent",
          "bulletedList",
          "numberedList",
          "|",
          "undo",
          "redo",
        ],
      },
    })
      .then((editor) => {
        console.log(Array.from(editor.ui.componentFactory.names()));
        editor.model.document.on("change:data", () => {
          target_input.value = editor.getData();
          target_input.dispatchEvent(new Event("change", { bubbles: true }));
        });
      })
      .catch((error) => {
        console.error(error);
      });
  },
};

Hooks.DateTimePicker = {
  mounted() {
    datetimehook(this.el);
  },

  updated() {
    datetimehook(this.el);
  },
};

Hooks.TriggerChange = {
  updated() {
    this.el.dispatchEvent(new Event("change", { bubbles: true }));
  },
};

Hooks.DragDropRepeater = {
  mounted() {
    let dragged = null;
    let selected = null;
    this.el.addEventListener("touchstart", (e) => (selected = e.target));
    this.el.addEventListener("mousedown", (e) => (selected = e.target));

    this.el.addEventListener("dragstart", (e) => {
      if ($(selected).closest(".form-repeater__item--drag-handle").length > 0) {
        dragged = $(e.target).closest(".form-repeater__item");
        dragged.addClass("form-repeater__item--dragging");
        e.dataTransfer.setData("text/plain", "handle");
      } else {
        e.preventDefault();
      }
    });

    this.el.addEventListener("dragover", (e) => {
      e.preventDefault();
    });

    this.el.addEventListener("dragleave", (e) => {
      const target = $(e.target).closest(".form-repeater__item");
      target.removeClass("form-repeater__item--drag-target");
    });

    this.el.addEventListener("dragenter", (e) => {
      const target = $(e.target).closest(".form-repeater__item");
      target.addClass("form-repeater__item--drag-target");
    });

    this.el.addEventListener("dragend", (e) => {
      dragged.removeClass("form-repeater__item--dragging");
    });

    this.el.addEventListener("drop", (e) => {
      const target = $(e.target).closest(".form-repeater__item");

      console.log(target, dragged);

      if (target[0] && dragged[0]) {
        this.pushEventTo("#" + this.el.id, "form_repeater.swap", {
          swap: [dragged.data("index"), target.data("index")],
        });
      }
    });
  },
};

function datetimehook(el) {
  const displayFormat = el.dataset.displayFormat || "MMMM Do, YYYY @ LT";
  const minDate =
    el.dataset.minDate === undefined ? moment() : el.dataset.minDate;
  const placeholder = el.getAttribute("placeholder") || "Select a date & time";

  const label = $("label[for=" + el.id + "]").addClass(
      "date-time-picker__label"
    ),
    initialValue = el.value && moment(el.value),
    updateDateTime = (date) => {
      displayDateTime(date);

      el.value = date ? date.format("YYYY-MM-DD HH:mm:ssZ") : "";

      el.dispatchEvent(new Event("change", { bubbles: true }));
    },
    displayDateTime = (date) => {
      if (date) {
        label
          .removeClass("date-time-picker__placeholder")
          .text(date.format(displayFormat));
      } else {
        label.addClass("date-time-picker__placeholder").text(placeholder);
      }
    };

  $(el)
    .daterangepicker({
      singleDatePicker: true,
      showDropdowns: true,
      timePicker: true,
      autoUpdateInput: false,
      startDate: initialValue || moment(),
      minDate: minDate,
      maxDate: moment().add(1, "Y"),
      locale: {
        cancelLabel: "Clear",
      },
    })
    .addClass("date-time-picker__input")
    .css({
      visibility: "hidden",
      width: 0,
      position: "absolute",
    });

  $(el).on("apply.daterangepicker", function (ev, picker) {
    updateDateTime(picker.startDate);
  });

  $(el).on("cancel.daterangepicker", function (ev, picker) {
    updateDateTime(null);
  });

  displayDateTime(initialValue);
}

export default Hooks;
