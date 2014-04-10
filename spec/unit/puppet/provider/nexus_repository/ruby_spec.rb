require 'spec_helper'

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
      Nexus::Rest.should_receive(:get_all).with('/service/local/repositories').and_return({'data' => [{'id' => 'repository-1'}, {'id' => 'repository-2'}]})
      provider_class.instances
    end

    it { instances.should have(2).items }
  end

  describe 'an instance' do
    let :instance do
      Nexus::Rest.should_receive(:get_all).with('/service/local/repositories').and_return({'data' => [{'id' => 'repository-1'}]})
      provider_class.instances[0]
    end

    it { instance.name.should == 'repository-1' }
    it { instance.exists?.should be_true }
  end

  it "should return false if it is not existing" do
    # the dummy example isn't returned by self.instances
    provider.exists?.should be_false
  end
  it 'should use /service/local/repositories to create a new resource' do
    Nexus::Rest.should_receive(:create).with('/service/local/repositories')
    provider.create
  end
  it 'should use /service/local/repositories/example to update an existing resource' do
    Nexus::Rest.should_receive(:update).with('/service/local/repositories/example')
    provider.update
  end
  it 'should use /service/local/repositories/example to delete an existing resource' do
    Nexus::Rest.should_receive(:destroy).with('/service/local/repositories/example')
    provider.destroy
  end
end
