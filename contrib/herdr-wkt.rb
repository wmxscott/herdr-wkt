# Draft formula for wmxscott/homebrew-tap. Fill in url and sha256 from the
# v1.0.0 release tarball before copying it to Formula/herdr-wkt.rb.
class HerdrWkt < Formula
  desc "Git worktrees that open as Herdr workspaces"
  homepage "https://github.com/wmxscott/herdr-wkt"
  url "https://github.com/wmxscott/herdr-wkt/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/wmxscott/herdr-wkt.git", branch: "main"

  uses_from_macos "git"
  uses_from_macos "zsh"

  def install
    bin.install "bin/herdr-wkt"
    bin.install_symlink "herdr-wkt" => "wkt"
  end

  test do
    assert_match "herdr-wkt #{version}", shell_output("#{bin}/herdr-wkt --version")
    assert_match "Usage: wkt <command>", shell_output("#{bin}/wkt --help")

    # Stand-in herdr, so the test never talks to a real Herdr session.
    (testpath/"stub/herdr").write <<~SH
      #!/bin/sh
      echo "$*" >> "#{testpath}/herdr.log"
    SH
    chmod 0755, testpath/"stub/herdr"
    ENV.prepend_path "PATH", testpath/"stub"

    ENV["GIT_AUTHOR_NAME"] = ENV["GIT_COMMITTER_NAME"] = "Test"
    ENV["GIT_AUTHOR_EMAIL"] = ENV["GIT_COMMITTER_EMAIL"] = "test@example.com"
    system "git", "init", "--quiet", "--initial-branch=main", "src"
    system "git", "-C", "src", "commit", "--quiet", "--allow-empty", "-m", "initial"
    system "git", "clone", "--quiet", "--bare", "src", "origin.git"

    mkdir "layout" do
      system bin/"wkt", "setup", testpath/"origin.git"
      cd "main" do
        assert_match "opened in Herdr", shell_output("#{bin}/wkt new -b topic")
      end
    end
    assert_equal "topic", shell_output("git -C #{testpath}/layout/topic branch --show-current").chomp
    assert_match "worktree open", (testpath/"herdr.log").read
  end
end
