# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_notifications_push/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  GENERATOR = RecordingStudioNotificationsPush::Generators::MigrationsGenerator

  def test_copies_engine_migrations_and_skips_ones_the_host_already_has
    in_app do |dir|
      output = run_generator(dir)

      copied = Dir.glob(File.join(dir, "db/migrate/*_create_recording_studio_notifications_push_installations.rb"))
      assert_equal 1, copied.size
      pattern = /\A\d{14}_create_recording_studio_notifications_push_installations\.rb\z/
      assert_match(pattern, File.basename(copied.first))
      assert_equal File.read(engine_migration), File.read(copied.first)
      assert_includes output, "Run 'bin/rails db:migrate'"

      run_generator(dir)

      assert_equal copied, Dir.glob(File.join(dir, "db/migrate/*.rb"))
    end
  end

  def test_copies_again_when_asked_not_to_skip_and_uses_a_new_timestamp
    in_app do |dir|
      run_generator(dir)
      run_generator(dir, skip_existing: false)

      copied = Dir.glob(File.join(dir, "db/migrate/*_create_recording_studio_notifications_push_installations.rb"))
      assert_equal 2, copied.size
      stamps = copied.map { |path| File.basename(path).split("_").first }
      refute_equal stamps[0], stamps[1]
      copied.each { |path| assert_equal File.read(engine_migration), File.read(path) }
    end
  end

  def test_gives_each_migration_its_own_timestamp
    with_source_root do |source|
      write_migration(
        source,
        "20200101000000_create_widgets.rb",
        "class CreateWidgets < ActiveRecord::Migration[8.1]; end\n"
      )
      write_migration(
        source,
        "20200101000001_add_widget_labels.rb",
        "class AddWidgetLabels < ActiveRecord::Migration[8.1]; end\n"
      )

      in_app do |dir|
        output = run_generator(dir)
        files = Dir.glob(File.join(dir, "db/migrate/*.rb"))
        assert_equal 2, files.size
        assert_includes output, "Found 2 migration(s)"
        stamps = files.map { |path| File.basename(path).split("_").first }
        refute_equal stamps[0], stamps[1]
        assert_equal "class CreateWidgets < ActiveRecord::Migration[8.1]; end\n",
                     File.read(files.find { |path| path.end_with?("create_widgets.rb") })
        assert_equal "class AddWidgetLabels < ActiveRecord::Migration[8.1]; end\n",
                     File.read(files.find { |path| path.end_with?("add_widget_labels.rb") })
      end
    end
  end

  def test_says_when_the_engine_has_no_migrations_directory
    with_source_root do |_source|
      in_app do |dir|
        output = run_generator(dir)

        assert_includes output, "No migrations found in RecordingStudioNotificationsPush engine."
        assert_empty Dir.glob(File.join(dir, "db/migrate/*.rb"))
      end
    end
  end

  def test_says_when_the_migrations_directory_is_empty
    with_source_root do |source|
      FileUtils.mkdir_p(File.join(source, "db/migrate"))

      in_app do |dir|
        output = run_generator(dir)

        assert_includes output, "No migrations found in RecordingStudioNotificationsPush engine."
        assert_empty Dir.glob(File.join(dir, "db/migrate/*.rb"))
      end
    end
  end

  private

  def engine_migration
    File.expand_path(
      "../db/migrate/20260824120000_create_recording_studio_notifications_push_installations.rb",
      __dir__
    )
  end

  def in_app
    previous = Dir.pwd
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      yield dir
    end
  ensure
    Dir.chdir(previous) if previous
  end

  def with_source_root
    previous = GENERATOR.source_root
    Dir.mktmpdir do |dir|
      GENERATOR.source_root(dir)
      yield dir
    end
  ensure
    GENERATOR.source_root(previous) if previous
  end

  def write_migration(source, name, body)
    FileUtils.mkdir_p(File.join(source, "db/migrate"))
    File.write(File.join(source, "db/migrate", name), body)
  end

  def run_generator(dir, skip_existing: true)
    capture_output do
      GENERATOR.new([], { skip_existing: skip_existing }, destination_root: dir).copy_migrations
    end
  end

  def capture_output
    previous = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = previous
  end
end
