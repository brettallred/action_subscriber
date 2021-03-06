class InstaSubscriber < ActionSubscriber::Base
  around_filter :whisper
  around_filter :yell

  def first
    $messages << payload
  end

  private

  def whisper
    $messages << :whisper_before
    yield
    $messages << :whisper_after
  end

  def yell
    $messages << :yell_before
    yield
    $messages << :yell_after
  end
end

describe "subscriber filters", :integration => true do
  let(:draw_routes) do
    ::ActionSubscriber.draw_routes do
      default_routes_for InstaSubscriber
    end
  end
  let(:subscriber) { InstaSubscriber }

  it "runs multiple around filters" do
    $messages = []  #testing the order of things
    ::ActionSubscriber.auto_subscribe!
    ::ActionSubscriber::Publisher.publish("insta.first", "hEY Guyz!", "events")

    verify_expectation_within(1.0) do
      expect($messages).to eq [:whisper_before, :yell_before, "hEY Guyz!", :yell_after, :whisper_after]
    end
  end
end
