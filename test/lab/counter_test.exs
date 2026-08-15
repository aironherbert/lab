defmodule Lab.CounterTest do
  use ExUnit.Case, async: true

  test "keeps and changes state through messages" do
    name = Module.concat(__MODULE__, TestCounter)
    start_supervised!({Lab.Counter, name: name})

    assert Lab.Counter.value(name) == 0

    Lab.Counter.increment(name)
    assert Lab.Counter.value(name) == 1

    Lab.Counter.decrement(name)
    assert Lab.Counter.value(name) == 0

    Lab.Counter.increment(name)
    Lab.Counter.reset(name)
    assert Lab.Counter.value(name) == 0
  end
end
