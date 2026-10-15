require "test_helper"

class ScheduleDataTest < ActiveSupport::TestCase
  test "ordering, case and formatting changes do not change the timetable" do
    previous = [ { date: "October 17, 2026", time: "10 AM", team1: "Falcons", team2: "TBD", location: nil }, { date: "2026-10-17", time: "2:30 PM", team1: "Owls", team2: "Bears", location: "Field 1" } ]
    current = [ { date: "2026-10-17", time: "14:30", team1: "owls", team2: "bears", location: "field 1", status: "scheduled" }, { date: "2026-10-17", time: "10:00", team1: " falcons ", team2: nil, location: "TBD", status: "scheduled" } ]
    assert_equal ScheduleData.normalize(previous), ScheduleData.normalize(current)
  end

  test "real time and cancellation changes remain detectable" do
    original = ScheduleData.normalize([ { date: "2026-10-17", time: "10:00", team1: "A", team2: "B", location: "Field 1" } ])
    changed = ScheduleData.normalize([ { date: "2026-10-17", time: "11:00", team1: "A", team2: "B", location: "Field 1", status: "cancelled" } ])
    assert_not_equal original, changed
    summary = ScheduleData.change_summary(original, changed)
    assert_includes summary, "10:00"
    assert_includes summary, "11:00"
    assert_includes summary, "cancelled"
  end
end
