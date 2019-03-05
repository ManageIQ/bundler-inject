RSpec.describe Spec::Helpers do
  it "are using the correct version of bundler" do
    write_gemfile <<~G
      source "https://rubygems.org"
      gem "rack", "=2.0.6"
    G
    bundle(:update)

    expect(lockfile.bundler_version.to_s).to eq(bundler_version)
    expect(lockfile_specs).to eq [["rack", "2.0.6"]]
  end
end
