%{
  configs: [
    %{
      name: "default",
      strict: false,
      checks: [
        {Credo.Check.Design.TagTODO, false},
        # We will want to bring this check back once we have upgraded phoenix and refactor stacked templates + data tables
        {Credo.Check.Refactor.LongQuoteBlocks, false},
        # TODO: Add moduledocs to project so this can be brought back
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 99999, trailing_digits: [2, 4]}
      ]
    }
  ]
}
