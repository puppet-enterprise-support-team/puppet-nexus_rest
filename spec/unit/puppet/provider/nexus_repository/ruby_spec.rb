require 'spec_helper'
include WebMock::API

provider_class = Puppet::Type.type(:nexus_repository).provider(:ruby)

describe provider_class do
  let :provider do
    resource = Puppet::Type::Nexus_repository.new(
      {
          :name     => 'example',
          :baseurl  => 'http://example.com',
          :resource => "/api/users",
          :timeout  => 10
      }
    )
    provider_class.new(resource)
  end

  describe 'instances' do
    let :instances do
      stub_request(:any, 'example.com/service/local/repositories').to_return(:body => '{ "data": [{"id": "repository-1"}, {"id": "repository-2"}] }')
      provider_class.instances
    end

    it { instances.should have(2).items }
  end

  describe 'an instance' do
    let :instance do
      stub_request(:any, 'example.com/service/local/repositories').to_return(:body => '{ "data": [{"id": "repository-1"}] }')
      provider_class.instances[0]
    end

    it { instance.name.should == 'repository-1' }
    it { instance.exists?.should be_true }
  end

  describe "exists" do
    it "should return false if resource is not existing" do
      # the dummy example isn't returned by self.instances
      provider.exists?.should be_false
    end
  end

  describe 'create' do
    it 'should submit a POST to /service/local/repositories' do
      stub = stub_request(:post, 'example.com/service/local/repositories').to_return(:status => 200)
      provider.create
      stub.should have_been_requested
    end

    it 'should raise an error if response is not expected' do
      stub_request(:any, 'example.com/service/local/repositories').to_return(:status => 503)
      expect { provider.create }.to raise_error
    end
  end

  describe 'update' do
    it 'should submit a PUT to /service/local/repositories/example' do
      stub = stub_request(:put, 'example.com/service/local/repositories/example').to_return(:status => 200)
      provider.update
      stub.should have_been_requested
    end

    it 'should raise an error if response is not expected' do
      stub_request(:any, 'example.com/service/local/repositories/example').to_return(:status => 503)
      expect { provider.update }.to raise_error
    end
  end

  describe 'destroy' do
    it 'should submit a DELETE to /service/local/repositories/example' do
      stub = stub_request(:delete, 'example.com/service/local/repositories/example').to_return(:status => 200)
      provider.destroy
      stub.should have_been_requested
    end

    it 'should not fail if resource already deleted' do
      stub = stub_request(:delete, 'example.com/service/local/repositories/example').to_return(:status => 404)
      provider.destroy
      stub.should have_been_requested
    end

    it 'should raise an error if response is not expected' do
      stub_request(:delete, 'example.com/service/local/repositories/example').to_return(:status => 503)
      expect { provider.destroy }.to raise_error
    end
  end
end
