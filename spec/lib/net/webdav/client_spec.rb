# coding: utf-8
require 'spec_helper'

RSpec.describe Net::Webdav::Client do
  let(:server_url) { 'https://example.com:5453' }
  let(:file_path) { '/system/foo.txt' }
  let(:client) { described_class.new(server_url) }
  let(:timeout_server) { 'http://web:4567' }

  describe 'initialize instance fields' do
    context 'default options' do
      let(:client) { described_class.new('https://andy:qwerty@example.com:5453/fiz') }

      it do
        expect(client.host).to eq 'https://example.com:5453'
        expect(client.username).to eq 'andy'
        expect(client.password).to eq 'qwerty'
        expect(client.url).to eq 'https://example.com:5453/fiz'
        expect(client.http_auth_types).to eq :basic
      end
    end

    context 'when passed credentials' do
      let(:client) { described_class.new('https://example.com:5453/fiz', username: 'andrew', password: 'qwerty') }

      before do
        stub_request(:head, 'https://example.com:5453/fiz/1.txt').with(basic_auth: ['andrew', 'qwerty']).to_return(status: 204)
      end

      it do
        expect(client.username).to eq 'andrew'
        expect(client.password).to eq 'qwerty'
        expect(client.file_exists?('/1.txt')).to be_truthy
      end
    end
  end

  describe '#file_exists?' do
    context 'file_path relative' do
      let(:file_path) { 'system/foo.txt' }

      before do
        stub_request(:head, "#{server_url}/#{file_path}").to_return(status: 204)
      end

      it do
        expect(client.file_exists?(file_path)).to be_truthy
      end
    end

    context 'when server responds with success' do
      before do
        stub_request(:head, "#{server_url}#{file_path}").to_return(status: 204)
      end

      it do
        expect(client.file_exists?(file_path)).to be_truthy
      end
    end

    context 'when timeout of operation reached' do
      let(:client) { described_class.new(timeout_server, timeout: 1) }

      it do
        expect { client.file_exists?(file_path) }.to raise_error Timeout::Error
      end
    end
  end

  describe '#get_file' do
    let(:local_file_path) { '/tmp/foo.txt' }

    context 'when download file' do
      before do
        stub_request(:get, "#{server_url}#{file_path}").to_return(status: 200, body: 'abcd')

        client.get_file(file_path, local_file_path)
      end

      after do
        FileUtils.rm('/tmp/foo.txt')
      end

      it do
        expect(File.read(local_file_path)).to eq 'abcd'
      end
    end

    context 'when timed out server' do
      let(:client) { described_class.new(timeout_server, timeout: 1) }

      it do
        expect { client.get_file(file_path, local_file_path) }.to raise_error Timeout::Error
      end
    end
  end

  describe '#put_file' do
    let(:file) { Tempfile.new('foo') }

    after { file.unlink }

    context 'when put file' do
      before do
        stub_request(:put, "#{server_url}#{file_path}").to_return(status: 201)
      end

      it do
        expect(client.put_file(file_path, file)).to eq 201
      end
    end

    context 'when bad response' do
      before do
        stub_request(:put, "#{server_url}#{file_path}").to_return(status: 500)
      end

      it do
        expect { client.put_file(file_path, file) }.to raise_error StandardError
      end
    end

    context 'when very slow server' do
      let(:client) { described_class.new(timeout_server, timeout: 1) }

      it do
        expect { client.put_file(file_path, file) }.to raise_error Timeout::Error
      end
    end
  end

  describe '#delete_file' do
    context 'when delete file' do
      before do
        stub_request(:delete, "#{server_url}#{file_path}").to_return(status: 200)
      end

      it do
        expect(client.delete_file(file_path)).to be_truthy
      end
    end

    context 'when very slow server' do
      let(:client) { described_class.new(timeout_server, timeout: 1) }

      it do
        expect { client.delete_file(file_path) }.to raise_error Timeout::Error
      end
    end

    context 'when empty path' do
      let(:file_path) { '' }

      before { stub_request(:delete, "#{server_url}#{file_path}").to_return(status: 200) }

      it { expect { client.delete_file(file_path) }.to raise_error ArgumentError }
    end

    context 'when slash path' do
      let(:file_path) { '/' }

      before { stub_request(:delete, "#{server_url}#{file_path}").to_return(status: 200) }

      it { expect { client.delete_file(file_path) }.to raise_error ArgumentError }
    end
  end
end
