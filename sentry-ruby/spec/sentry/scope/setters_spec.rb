require "spec_helper"

RSpec.describe Sentry::Scope do
  let(:new_breadcrumb) do
    new_breadcrumb = Sentry::Breadcrumb.new
    new_breadcrumb.message = "foo"
    new_breadcrumb
  end

  describe "#set_user" do
    it "raises error when passed non-hash argument" do
      expect do
        subject.set_user(1)
      end.to raise_error(ArgumentError)
    end

    it "sets the user" do
      subject.set_user({id: 1, name: "Jack"})

      expect(subject.user).to eq({id: 1, name: "Jack"})
    end

    it "unsets user when given empty data" do
      subject.user = {id: 1, name: "Jack"}

      subject.set_user({})

      expect(subject.user).to eq({})
    end
  end

  describe "#set_extras" do
    it "raises error when passed non-hash argument" do
      expect do
        subject.set_extras(1)
      end.to raise_error(ArgumentError)
    end

    it "replaces the extra hash" do
      subject.extra = {bar: "baz"}

      subject.set_extras({foo: "bar"})

      expect(subject.extra).to eq({foo: "bar"})
    end
  end

  describe "#set_extra" do
    it "merges the key value with existing extra" do
      subject.extra = {bar: "baz"}

      subject.set_extra(:foo, "bar")

      expect(subject.extra).to eq({foo: "bar", bar: "baz"})
    end
  end

  describe "#set_contexts" do
    it "raises error when passed non-hash argument" do
      expect do
        subject.set_contexts(1)
      end.to raise_error(ArgumentError)
    end

    it "replaces the context hash" do
      subject.contexts = {bar: "baz"}

      subject.set_contexts({foo: "bar"})

      expect(subject.contexts).to eq({foo: "bar"})
    end
  end

  describe "#set_context" do
    it "merges the key value with existing context" do
      subject.contexts = {bar: "baz"}

      subject.set_context(:foo, "bar")

      expect(subject.contexts).to eq({foo: "bar", bar: "baz"})
    end
  end

  describe "#set_tags" do
    it "raises error when passed non-hash argument" do
      expect do
        subject.set_tags(1)
      end.to raise_error(ArgumentError)
    end

    it "replaces the tag hash" do
      subject.tags = {bar: "baz"}

      subject.set_tags({foo: "bar"})

      expect(subject.tags).to eq({foo: "bar"})
    end
  end

  describe "#set_tag" do
    it "merges the key value with existing tag" do
      subject.tags = {bar: "baz"}

      subject.set_tag(:foo, "bar")

      expect(subject.tags).to eq({foo: "bar", bar: "baz"})
    end
  end

  describe "#set_level" do
    it "sets the scope's level" do
      subject.set_level(:info)

      expect(subject.level).to eq(:info)
    end
  end

  describe "#set_transaction" do
    it "pushes the transaction to transactions stack" do
      subject.set_transaction("WelcomeController#home")

      expect(subject.transaction).to eq("WelcomeController#home")
    end
  end

  describe "#set_fingerprint" do
    it "replaces the fingerprint" do
      subject.set_fingerprint(["foo"])

      expect(subject.fingerprint).to eq(["foo"])

      subject.set_fingerprint(["bar"])

      expect(subject.fingerprint).to eq(["bar"])
    end
  end
end
