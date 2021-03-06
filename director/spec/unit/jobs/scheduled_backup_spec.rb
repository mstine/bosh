require 'spec_helper'
require 'blobstore_client'
require 'fakefs/spec_helpers'

describe Bosh::Director::Jobs::ScheduledBackup do
  include FakeFS::SpecHelpers

  let(:backup_job) { instance_double('Bosh::Director::Jobs::Backup', backup_file: 'backup_dest') }
  let(:backup_destination) { instance_double('Bosh::Blobstore::BaseClient', create: nil) }
  let(:task) { described_class.new(backup_job: backup_job, backup_destination: backup_destination) }

  before do
    backup_job.stub(:perform) { FileUtils.touch 'backup_dest' }
    Time.stub(now: Time.parse('2013-07-02T09:55:40Z'))
  end

  describe 'Resque job class expectations' do
    let(:job_type) { :scheduled_backup }
    it_behaves_like 'a Resque job'
  end

  describe 'perform' do
    it 'creates a backup' do
      backup_job.should_receive(:perform)
      task.perform
    end

    it 'pushes a backup to the destination blobstore' do
      backup_destination.should_receive(:create).with do |backup_file, file_name|
        expect(backup_file.path).to eq 'backup_dest'
        expect(file_name).to eq 'backup-2013-07-02T09:55:40Z.tgz'
      end
      task.perform
    end

    it 'returns a string when successful' do
      expect(task.perform).to eq "Stored `backup-2013-07-02T09:55:40Z.tgz' in backup blobstore"
    end
  end

  describe 'initialize' do
    let(:blobstores) { instance_double('Bosh::Director::Blobstores') }
    let(:backup_job_class) { class_double('Bosh::Director::Jobs::Backup').as_stubbed_const }
    let(:app_instance) { instance_double('Bosh::Director::App', blobstores: blobstores) }
    let!(:app_class) { class_double('Bosh::Director::App', instance: app_instance).as_stubbed_const }

    it 'injects defaults' do
      backup_job_class.should_receive(:new)

      blobstores.should_receive(:backup_destination)

      described_class.new
    end
  end
end