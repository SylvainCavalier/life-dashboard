require "test_helper"
require "minitest/mock"

class VideoDownloads::YtDlpServiceTest < ActiveSupport::TestCase
  Status = Struct.new(:ok) do
    def success? = ok
  end

  setup do
    @dir = Dir.mktmpdir("yt_dlp_service")
    @calls = []
  end

  teardown { FileUtils.rm_rf(@dir) }

  # Remplace Open3.capture3 : consigne chaque commande, renvoie les metadonnees
  # pour la passe --dump-json, ecrit un faux fichier pour le telechargement et
  # laisse passer le remux ffmpeg.
  def with_fake_binaries(metadata_stdout:, extension:, &)
    filepath = File.join(@dir, "Une video [abc].#{extension}")
    fake = lambda do |*command|
      @calls << command
      if command.first == "ffmpeg"
        File.write(command.last, "remux")
        [ "", "", Status.new(true) ]
      elsif command.include?("--dump-json")
        [ metadata_stdout, "", Status.new(true) ]
      else
        File.write(filepath, "contenu")
        [ "#{filepath}\n", "", Status.new(true) ]
      end
    end
    Open3.stub(:capture3, fake, &)
  end

  def download_call
    @calls.find { |command| command.include?("-o") }
  end

  test "le mp4 trie les formats par H.264 puis par resolution, sans filtre sur la hauteur" do
    with_fake_binaries(metadata_stdout: { title: "Une video" }.to_json, extension: "mp4") do
      VideoDownloads::YtDlpService.new(url: "https://x.com/a/status/1", format: "mp4",
                                       quality: "720p", output_dir: @dir).call
    end

    args = download_call
    assert_equal "bv*+ba/b", args[args.index("-f") + 1]
    assert_equal "vcodec:h264,res:720,acodec:aac", args[args.index("-S") + 1]
    assert_not args.join(" ").include?("height<="), "un filtre sur la hauteur degrade les videos verticales"
    assert_equal [ "--", "https://x.com/a/status/1" ], args.last(2)
  end

  test "la qualite originale plafonne a 1080 sur la plus petite dimension" do
    with_fake_binaries(metadata_stdout: { title: "Une video" }.to_json, extension: "mp4") do
      VideoDownloads::YtDlpService.new(url: "https://youtu.be/abc", format: "mp4",
                                       quality: "original", output_dir: @dir).call
    end

    assert_includes download_call, "vcodec:h264,res:1080,acodec:aac"
  end

  test "une seule video est demandee, y compris pour un tweet qui en contient plusieurs" do
    two_videos = [ { title: "Premiere", duration: 12.7 }, { title: "Seconde" } ].map(&:to_json).join("\n")

    result = with_fake_binaries(metadata_stdout: two_videos, extension: "mp4") do
      VideoDownloads::YtDlpService.new(url: "https://x.com/a/status/1", format: "mp4",
                                       quality: "original", output_dir: @dir).call
    end

    assert_equal "Premiere", result.title
    assert_equal 12, result.duration
    @calls.reject { |command| command.first == "ffmpeg" }.each do |command|
      index = command.index("--playlist-items")
      assert index, "--playlist-items attendu dans #{command.inspect}"
      assert_equal "1", command[index + 1]
    end
  end

  test "les metadonnees de source sont extraites, avec les replis prevus" do
    metadata = { title: "Une video", extractor_key: "Youtube", webpage_url: "https://www.youtube.com/watch?v=abc",
                 uploader: "Blender", channel: "Blender Studio", uploader_id: "@Blender",
                 uploader_url: "https://www.youtube.com/@Blender", channel_url: "https://www.youtube.com/channel/UC1",
                 timestamp: 1_415_628_355, upload_date: "20141110", view_count: 1234 }

    result = with_fake_binaries(metadata_stdout: metadata.to_json, extension: "mp4") do
      VideoDownloads::YtDlpService.new(url: "https://youtu.be/abc", format: "mp4",
                                       quality: "original", output_dir: @dir).call
    end

    assert_equal "Youtube", result.platform
    assert_equal "https://www.youtube.com/watch?v=abc", result.canonical_url
    assert_equal "Blender Studio", result.uploader
    assert_equal "@Blender", result.uploader_handle
    assert_equal "https://www.youtube.com/@Blender", result.uploader_url
    assert_equal Time.zone.at(1_415_628_355), result.published_at
    assert_equal 1234, result.view_count
  end

  test "sans timestamp ni URL d'auteur (Crowdbunker), la date vient de upload_date" do
    metadata = { title: "Une video", extractor_key: "CrowdBunker", uploader: "Un auteur", upload_date: "20260624" }

    result = with_fake_binaries(metadata_stdout: metadata.to_json, extension: "mp4") do
      VideoDownloads::YtDlpService.new(url: "https://crowdbunker.com/v/abc", format: "mp4",
                                       quality: "original", output_dir: @dir).call
    end

    assert_equal "Un auteur", result.uploader
    assert_nil result.uploader_url
    assert_equal Time.utc(2026, 6, 24), result.published_at
  end

  test "une erreur yt-dlp connue est completee par une piste en francais" do
    failing = ->(*) { [ "", "ERROR: [CrowdBunker] abc: No video formats found!", Status.new(false) ] }

    error = assert_raises(VideoDownloads::YtDlpService::Error) do
      Open3.stub(:capture3, failing) do
        VideoDownloads::YtDlpService.new(url: "https://crowdbunker.com/v/abc", format: "mp4",
                                         quality: "original", output_dir: @dir).call
      end
    end

    assert_match "No video formats found", error.message
    assert_match "Piste : aucun flux video", error.message
  end

  test "le mp3 extrait l'audio sans remux" do
    result = with_fake_binaries(metadata_stdout: { title: "Une video" }.to_json, extension: "mp3") do
      VideoDownloads::YtDlpService.new(url: "https://www.dailymotion.com/video/x1", format: "mp3",
                                       output_dir: @dir).call
    end

    assert_equal "Une video [abc].mp3", result.filename
    assert_includes download_call, "-x"
    assert @calls.none? { |command| command.first == "ffmpeg" }
  end

  test "des metadonnees vides levent une erreur lisible" do
    error = assert_raises(VideoDownloads::YtDlpService::Error) do
      with_fake_binaries(metadata_stdout: "\n", extension: "mp4") do
        VideoDownloads::YtDlpService.new(url: "https://x.com/a/status/1", format: "mp4",
                                         quality: "original", output_dir: @dir).call
      end
    end
    assert_match "Aucune video", error.message
  end
end
