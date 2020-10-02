require "spec_helper"

RSpec.describe Sentry::Scope do
  let(:new_breadcrumb) do
    new_breadcrumb = Sentry::Breadcrumb.new
    new_breadcrumb.message = "foo"
    new_breadcrumb
  end

  describe "#initialize" do
    it "contains correct defaults" do
      expect(subject.breadcrumbs).to be_a(Sentry::BreadcrumbBuffer)
      expect(subject.contexts.dig(:server, :os).keys).to match_array([:name, :version, :build, :kernel_version])
      expect(subject.contexts.dig(:server, :runtime, :version)).to match(/ruby/)
      expect(subject.extra).to eq({})
      expect(subject.tags).to eq({})
      expect(subject.user).to eq({})
      expect(subject.fingerprint).to eq([])
      expect(subject.transactions).to eq([])
    end
  end

  describe "#dup" do
    it "copies the values instead of just references to values" do
      copy = subject.dup

      copy.breadcrumbs.record(new_breadcrumb)
      copy.contexts.merge!(server: {os: {}})
      copy.extra.merge!(foo: "bar")
      copy.tags.merge!(foo: "bar")
      copy.user.merge!(foo: "bar")
      copy.transactions << "foo"
      copy.fingerprint << "bar"

      expect(subject.breadcrumbs.to_hash).to eq({ values: [] })
      expect(subject.contexts.dig(:server, :os).keys).to match_array([:name, :version, :build, :kernel_version])
      expect(subject.contexts.dig(:server, :runtime, :version)).to match(/ruby/)
      expect(subject.extra).to eq({})
      expect(subject.tags).to eq({})
      expect(subject.user).to eq({})
      expect(subject.fingerprint).to eq([])
      expect(subject.transactions).to eq([])
    end
  end

  describe "#add_breadcrumb" do
    it "adds the breadcrumb to the buffer" do
      expect(subject.breadcrumbs.empty?).to eq(true)

      subject.add_breadcrumb(new_breadcrumb)

      expect(subject.breadcrumbs.peek).to eq(new_breadcrumb)
    end
  end

  describe "#clear_breadcrumbs" do
    before do
      subject.add_breadcrumb(new_breadcrumb)

      expect(subject.breadcrumbs.peek).to eq(new_breadcrumb)
    end

    it "clears all breadcrumbs by replacing the buffer object" do
      subject.clear_breadcrumbs

      expect(subject.breadcrumbs.empty?).to eq(true)
    end
  end

  describe "#apply_to_event" do
    subject do
      scope = described_class.new
      scope.tags = {foo: "bar"}
      scope.extra = {additional_info: "hello"}
      scope.user = {id: 1}
      scope.transactions = ["WelcomeController#index"]
      scope.fingerprint = ["foo"]
      scope
    end
    let(:client) do
      Sentry::Client.new(Sentry::Configuration.new.tap { |c| c.scheme = "dummy" } )
    end
    let(:event) do
      client.event_from_message("test message")
    end

    it "applies the contextual data to event" do
      subject.apply_to_event(event)
      expect(event.tags).to eq({foo: "bar"})
      expect(event.user).to eq({id: 1})
      expect(event.extra).to eq({additional_info: "hello"})
      expect(event.transaction).to eq("WelcomeController#index")
      expect(event.breadcrumbs).to be_a(Sentry::BreadcrumbBuffer)
      expect(event.fingerprint).to eq(["foo"])
      expect(event.contexts.dig(:server, :os).keys).to match_array([:name, :version, :build, :kernel_version])
      expect(event.contexts.dig(:server, :runtime, :version)).to match(/ruby/)
    end

    it "doesn't override event's pre-existing data" do
      event.tags = {foo: "baz"}
      event.user = {id: 2}
      event.extra = {additional_info: "nothing"}
      event.contexts = {server: nil}

      subject.apply_to_event(event)
      expect(event.tags).to eq({foo: "baz"})
      expect(event.user).to eq({id: 2})
      expect(event.extra[:additional_info]).to eq("nothing")
      expect(event.contexts[:server]).to eq(nil)
    end
  end
end
