# rspec\_test\_data - Create Complex test data with the ability to share with other tests or seed data

[![<sustainable-rails>](https://circleci.com/gh/sustainable-rails/rubygem.svg?style=shield)](https://app.circleci.com/pipelines/github/sustainable-rails/rubygem)

## Install

```ruby
# In your Gemfile
gem "rspec_test_data"
```

*Note*: Nothing is required when you do this. You *must* configure things. See below.

## What Problem Does This Solve?

This allows the creation of test data that is more than one factory, but scoped to a test file.

Rails comes with the concept of *fixtures* which is a global set of data that is available to all of your tests.  Many developers, myself
included, find this is hard to manage when an app becomes non-trivial, and can get extremely complicated when you use and validate
foreign key constraints.

[FactoryBot](https://github.com/thoughtbot/factory_bot) provides an alternative, which are *factories* to create instances of objects you
would use as input to a test.  These work great for creating single objects.  They do not work as great when you need to create a lot of
objects.

*Why would you need to create a lot of objects?*  Glad you asked.  A very common reason in my experience is if you are writing some code
that needs to perform a query that is complex.  For example, show me all the customers who have said they have insurance, but who have
not provided the details of their insurance, but filter out everyone that has not scheduled an appointment.

Testing this requires creating several records in all the various states to check your query logic, then running the query and figuring
out what came back.

*OK, so use factories* - for a single test, it *is* better to just use factories to create a bunch of stuff.  But, when you start needing
to create them in more than one test, or want to have that data in your seed data for local development, RSpec provides very rudimentary
tools for this.  Since RSpec uses an internal DSL via `let` and `shared_context` and friends, it is hard to manage, compose, and re-use
this stuff.

But! We have *Object-Oriented Programming*! If we could put this stuff in a class, we can use that class, make that class configurable
(or not), extend that class, etc. We can use the tools we use every day to manage our complex test data.

*OK, so why do I need a gem?*  This gem facilitates that by providing an implicit `test_data` object that allows access to a test data
class you define.

## Using This Gem

Suppose you have `spec/services/appointments_spec.rb`:

```ruby
RSpec.describe Appointments do
  describe "#upcoming" do
    context "no restriction by service" do
      it "returns all in the future" do
        a1       = create(:appointment,            date: 4.days.from_now)
        a2       = create(:appointment,            date: 14.days.from_now)
        canceled = create(:appointment, :canceled, date: 3.days.from_now)
        past     = create(:appointment,            date: 3.days.ago)

        upcoming = appointments.upcoming

        expect(upcoming.size).to eq(2)
        aggregate_failures do
          expect(upcoming).to include(a1)
          expect(upcoming).to include(a2)
        end
      end
    end
    context "restrict by service" do
      it "returns those in the future for the given service" do
        s1 = create(:service)
        s2 = create(:service)

        a1       = create(:appointment,            service: s1, date: 4.days.from_now)
        a2       = create(:appointment,            service: s2, date: 14.days.from_now)
        canceled = create(:appointment, :canceled, service: s1, date: 3.days.from_now)
        past     = create(:appointment,            service: s1, date: 3.days.ago)

        upcoming = appointments.upcoming(service: s1)

        expect(upcoming.size).to eq(1)
        expect(upcoming).to      include(a1)
      end
    end
  end
end
```

The test set up for both tests is pretty similar.  The first test does not specify the service, but the service doesn't matter to that test, so it could absolutely use the exact same set of services and appointments that the second test uses.

It also might be nice to use this setup when you are working on the front-end to have some realistic data or as part of a larger set of
test data for a system test that involves this code.

We could put that in a `before` block or a series of `let` calls, but this doesn't make it easy to use outside this test.  Enter
`rspec_test_data`.

Assuming you have configured this gem, you would create the class `RspecTestData::Services::Appointments` in the file
`spec/services/appointments.test_data.rb` like so:

```ruby
module RspecTestData::Services
  class Appointments < RspecTestData::BaseTestData

    attr_reader :service, :upcoming_appointment_service, :upcoming_appointment_other_service

    def initialize
      @service      = create(:service)
      other_service = create(:service)

      @upcoming_appointment_service       = create(:appointment,
                                                   service: s1,
                                                   date: 4.days.from_now)
      @upcoming_appointment_other_service = create(:appointment,
                                                   service: s2,
                                                   date: 14.days.from_now)
      canceled                            = create(:appointment, :canceled,
                                                   service: s1,
                                                   date: 3.days.from_now)
      past                                = create(:appointment,
                                                    service: s1,
                                                    date: 3.days.ago)
    end
  end
end
```

This class creates the test data and exposes only the data the test is going to need.  Now, the test looks like so:

```ruby
RSpec.describe Appointments do
  describe "#upcoming" do
    context "no restriction by service" do
      it "returns all in the future" do
        upcoming = appointments.upcoming

        expect(upcoming.size).to eq(2)

        aggregate_failures do
          expect(upcoming).to include(test_data.upcoming_appointment_service)
          expect(upcoming).to include(test_data.upcoming_appointment_other_service)
        end
      end
    end
    context "restrict by service" do
      it "returns those in the future for the given service" do
        upcoming = appointments.upcoming(service: test_data.service)

        expect(upcoming.size).to eq(1)
        expect(upcoming).to      include(test_data.upcoming_appointment_service)
      end
    end
  end
end
```

Whoa.  Yes, the setup is gone and subsumed into the test data class.  This is a trade-off.  You make this trade-off in this case because
you want access to the test data outside this class.  You can achieve this like so, in your `db/seeds.rb`:

```ruby
require "rspec_test_data/seeds_helper"

test_data_seeds_helper = RspecTestData::SeedsHelper.for_rails
test_data = test_data_seeds_helper.load("RspecTestData::Services::Appointments")

puts test_data.upcoming_appointment_service.customer.name +
     " has an upcoming appointment with the service"
```

This can be extremely helpful for aligning your dev environment, where you may want realistic data to work on the UI, with your tests.

Note that since the test data class is just a class, it can accept arguments to the constructor that affect the behavior.  Perhaps you
want your seed data to be a bit more realistic:

```ruby
require "rspec_test_data/seeds_helper"

test_data_seeds_helper = RspecTestData::SeedsHelper.for_rails
test_data = test_data_seeds_helper.load("RspecTestData::Services::Appointments",
                                        service_name: "Physical Therapy")

puts test_data.upcoming_appointment_service.customer.name +
     " has an upcoming appointment for Physical Therapy"
```

The test data class accommodates this using plain ole Ruby:

```ruby
module RspecTestData::Services
  class Appointments < RspecTestData::BaseTestData

    attr_reader :service, :upcoming_appointment_service, :upcoming_appointment_other_service

    def initialize(service_name: :use_factory)
      @service      = if service_name == :use_factory
                        create(:service)
                      else
                        create(:service, name: service_name)
                      end
      other_service = create(:service)

      # ... as before

    end
  end
end
```

This class then becomes a sort of "super factory" you can use to create complex test data.  Suppose you want to search for upcoming
appointments by service name?  You'll need to make sure both services are created with distinct names so  you can reliably search by name

```ruby
module RspecTestData::Services
  class Appointments < RspecTestData::BaseTestData

    attr_reader :service, :upcoming_appointment_service, :upcoming_appointment_other_service

    def initialize(service_name:       :use_factory,
                   other_service_name: :use_factory)

      @service      = if service_name == :use_factory
                        create(:service)
                      else
                        create(:service, name: service_name)
                      end
      other_service = if other_service_name == :use_factory
                        create(:service)
                      else
                        create(:service, name: other_service_name)
                      end

      # ... as before

    end
  end
end
```

Now, in your test you can override the default creation of the test data per test.  If you declare a `let` variable named
`test_data_override`, *that* will be set to `test_data`.  To create this, you have access to the class via the implicitly defined
variable `test_data_class`.

```ruby
RSpec.describe Appointments do
  describe "#upcoming" do
    context "no restriction by service" do
      it "returns all in the future" # as before
    end
    context "restrict by service" do
      it "returns those in the future for the given service" # as before
    end
    context "restrict by service name partial match" do
      let(:test_data_override) {
        test_data_class.new(service_name:       "Physical Therapy",
                            other_service_name: "Ortho Exam")
      }
      it "returns those in the future for the given service" do
        upcoming = appointments.upcoming(service_name: "phys")

        expect(upcoming.size).to eq(1)
        expect(upcoming).to      include(test_data.upcoming_appointment_service)
      end
    end
  end
end
```

Notice how the *only* magic happening is the definition of `test_data` and `test_data_class` based on a convention of a class defined
in a file with a specific name.  The test data class is just a normal Ruby class.  Your test that overrides it just uses
Ruby.

You can opt out using RSpec metadata:

```ruby
RSpec.describe Appointments do
  describe "#upcoming" do
    context "no restriction by service" do
      it "returns all in the future" # as before
    end
    context "restrict by service" do
      it "returns those in the future for the given service" # as before
    end
    context "restrict by service name partial match", test_data: false do
      it "returns those in the future for the given service" do
        # test_data is not defined here - do whatever you want
      end
    end
  end
end
```

Test Data can also be useful for system tests.  Perhaps you want a system test of the appointment search feature.

```ruby
# spec/system/appointments/search_spec.rb
RSpec.describe "searching for appointments" do
  scenario "show all appointments" do
    login_as test_data.therapist

    click_on "Search Appointments"
    click_on "View All"

    expect(page).to     have_content(test_data.upcoming_appointment_service.description)
    expect(page).to     have_content(test_data.upcoming_appointment_other_service.description)
    expect(page).not_to have_content(test_data.canceled_appointment.description)
  end
end
```

To make this work, you'll need to define `RspecTestData::System::Appointments::Search` in the file
`spec/system/appointments/search.test_data.rb`.

To re-use the test data for the `Appointments` class, all you have to do is use a plain old Ruby concept: inheritance:

```ruby
require_relative "../services/appointments.test_data.rb"
class RspecTestData::System::Appointments::Search < RspecTestData::Services::Appointments
  attr_reader :therapist, :canceled_appointment
  def initialize(...)
    super(...)

    @therapist = create(:user, type: :therapist)

    @canceled_appointment = create(:appointment, :canceled,
                                   service: @service,
                                   date: 10.days.from_now)
  end
end
```

This gem isn't really facilitating this re-use - we can do it because this is just a class and Ruby allows it.  No new skills or DSL is
needed here. You can do whatever makes sense.

## Configuration & Setup

In your `spec/spec_helper.rb`:

```ruby
require "rspec_test_data/rspec_setup"    # brings in the setup below
require "rspec_test_data/base_test_data" # Avoid having to require this in all test data class files

RSpec.configure do |config|

  # whatever set up you have already

  config.before(:example) do |example|
    RspecTestData::Setup.new(example)
  end
end
```

Even here, the setup is explicit so you know it's happening. Nothing is done to you automatically.

If you don't create an analogous `.test_data.rb` file, nothing happens, your test works like normal.

## Debugging

Often, libraries with implicit behavior are hard to debug when nothing happens.  The library can't tell that you meant to do something
but failed - it just thinks you didn't try to do something.  To help debug those situations:

```
DEBUG_TEST_DATA=true bin/rspec spec/services/appointments_spec.rb
```

This will cause rspec\_test\_data to output verbose information about what it's doing, what it tried, what worked, what didn't.  You can also add the `debug_test_data: true`
metadata to any test or spec to trigger the same behavior.

## A Note on Implementation

I have been using this for several months in two Rails apps that I would say are "medium-small".  It is working great for me, but if you
look at the code for `RspecTestData::Setup`, there is a bit of wizardry in there.  Be careful with how you use this.

## Ejecting from the Magic

Since your test data class is just a class, you can eject from all of this like so:

1. Remove this Gem
2. Keep a copy of `RspecTestData::BaseTestData` in your app, e.g. in `lib/rspec_test_data/base_test_data.rb`
3. In your RSpec tests, add this:

   ```ruby
   require_relative "./appointments.test_data.rb"

   # Then, in a test...
   let(:test_data) { RspecTestData::Services::Appointments.new }
   ```

## Contributing

Would love feedback on the implementation and how it might be unit tested.
