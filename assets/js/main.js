$(function () {
  const dateRange = $("#daterange"),
    dateValue = dateRange.val();

  if (typeof dateValue !== "undefined") {
    const dates = dateRange.val().split(" - "),
      hasDates = dates.length === 2,
      startDate = hasDates ? moment(dates[0]) : undefined,
      endDate = hasDates ? moment(dates[1]) : undefined;

    dateRange.daterangepicker({
      ranges: {
        Today: [moment(), moment()],
        Yesterday: [moment().subtract(1, "days"), moment().subtract(1, "days")],
        "Last 7 Days": [moment().subtract(6, "days"), moment()],
        "Last 30 Days": [moment().subtract(29, "days"), moment()],
        "This Month": [moment().startOf("month"), moment().endOf("month")],
        "Last Month": [
          moment().subtract(1, "month").startOf("month"),
          moment().subtract(1, "month").endOf("month"),
        ],
      },
      locale: { cancelLabel: "Clear" },
      opens: "center",
      alwaysShowCalendars: true,
      buttonClasses: "button",
      applyButtonClasses: "button--primary",
      cancelButtonClasses: "button--secondary",
      autoUpdateInput: false,
      startDate,
      endDate,
    });
  }
});
