# Seamark builds from source on every platform because the tree-sitter
# bindings require CGO; CI-built bottles spare users the compile.
class Seamark < Formula
  desc "Local code intelligence, repo memory, and guardrails for coding agents"
  homepage "https://github.com/seamark-dev/seamark"
  url "https://github.com/seamark-dev/seamark/archive/refs/tags/v0.7.0.tar.gz"
  sha256 "b1456d2483cf953fd382cbe411e15a9abdfe9f2a7b8bf97c8c40bcd9bc46b451"
  license "Apache-2.0"
  head "https://github.com/seamark-dev/seamark.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/seamark-dev/homebrew-tap/releases/download/seamark-0.7.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "2ac36a0437902ce2c676866a8d49a0da77916a8603cf8dcaec61706a9873f789"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "e3114e09d076ba525b269e89f332fb43c7bf1a53393e459bfe1ac4ec8d4a338d"
    sha256 cellar: :any,                 x86_64_linux:  "eab3f95a7b80a12ea18a84a09f3d8cd9cd821cbaeb2bfbc8ead630c86ca6922d"
  end

  depends_on "go" => :build

  # History mining shells out to git at runtime, but Homebrew forbids
  # declaring it: every Homebrew install already guarantees git.

  def install
    # The source tarball has no git metadata, so `git describe` cannot
    # stamp the version; pass the tag through the same ldflag the
    # Makefile uses.
    ENV["CGO_ENABLED"] = "1"
    stamp = build.head? ? "HEAD-#{Utils.git_short_head}" : "v#{version}"
    ldflags = "-s -w -X github.com/seamark-dev/seamark/internal/cli.version=#{stamp}"

    system "go", "build", *std_go_args(ldflags:), "./cmd/seamark"

    generate_completions_from_executable(bin/"seamark", "completion")
  end

  def caveats
    <<~EOS
      Seamark indexes nothing until you run it inside a repository.
      To index your first repository:

        cd /path/to/repository
        seamark init
        seamark index
        seamark orient
    EOS
  end

  test do
    # Mirror scripts/release-smoke.sh from the main repository: exercise
    # the primary journey (init -> index -> why -> doctor) in a fresh git
    # fixture, so a bottle that cannot index a real repository fails here.
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    ENV["GIT_CONFIG_SYSTEM"] = File::NULL

    repo = testpath/"repo"
    repo.mkpath

    cd repo do
      system "git", "init", "-q", "-b", "main"
      system "git", "config", "user.name", "Homebrew Test"
      system "git", "config", "user.email", "test@example.com"

      # The fixture only gets indexed, never compiled, so the go.mod
      # needs no go directive; this mirrors scripts/release-smoke.sh.
      (repo/"go.mod").write "module example.com/demo\n"
      (repo/"main.go").write <<~GO
        package main

        func helper() int { return 41 }

        func main() { _ = helper() + 1 }
      GO

      system "git", "add", "-A"
      system "git", "commit", "-q", "-m", "initial"

      assert_match "gate", shell_output("#{bin}/seamark init")
      assert_match "symbols", shell_output("#{bin}/seamark index")
      assert_match "orientation", shell_output("#{bin}/seamark orient")
      assert_match "helper", shell_output("#{bin}/seamark why helper")

      system bin/"seamark", "doctor"
    end

    assert_match version.to_s, shell_output("#{bin}/seamark version") if build.stable?
  end
end
