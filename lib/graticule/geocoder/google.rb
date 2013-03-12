# encoding: UTF-8
module Graticule #:nodoc:
  module Geocoder #:nodoc:

    # First you need a Google Maps API key.  You can register for one here:
    # http://www.google.com/apis/maps/signup.html
    #
    #   gg = Graticule.service(:google).new(MAPS_API_KEY)
    #   location = gg.locate '1600 Amphitheater Pkwy, Mountain View, CA'
    #   p location.coordinates
    #   #=> [37.423111, -122.081783
    #
    class Google < Base
      # http://www.google.com/apis/maps/documentation/#Geocoding_HTTP_Request

      def initialize
        @url = URI.parse 'http://maps.googleapis.com/maps/api/geocode/xml'
      end

      # Locates +address+ returning a Location
      def locate(address)
        get :address => address.is_a?(String) ? address : location_from_params(address).to_s
      end

    private
      class Type
        include HappyMapper
        element :name, String, :tag => '.|.//text()'
      end

      class AddressComponent
        include HappyMapper
        tag 'address_component'
        has_many :types, Type
        element :short_name, String
        element :long_name, String
      end

      class Geometry
        include HappyMapper
        tag 'location'
        element :lat, Float, :tag => 'lat'
        element :lng, Float, :tag => 'lng'
      end

      class GeocodeResponse
        include HappyMapper
        tag 'GeocodeResponse'
        has_many :address_components, AddressComponent
        has_one :location, Geometry

        element :code, String, :tag => 'status'

        def get_type(type)
          address_components.detect {|component|  component.types.first.name == type } 
        end
      end

      def prepare_response(xml)
        GeocodeResponse.parse(xml, :single => true)
      end

      def parse_response(response) #:nodoc:
        Location.new(
          :latitude    => response.location.lat,
          :longitude   => response.location.lng,
          :street      => response.get_type('route').short_name,
          :locality    => response.get_type('locality').short_name,
          :region      => response.get_type('administrative_area_level_1').short_name,
          :postal_code => response.get_type('postal_code').short_name,
          :country     => response.get_type('country').short_name,
          :precision   => :unknown
        )
      end

      # Extracts and raises an error from +xml+, if any.
      def check_error(response) #:nodoc:
        case response.code
        when 'OK' then # ignore, ok
        when 'INVALID_REQUEST' then
          raise AddressError, 'missing address'
        when 'ZERO_RESULTS' then
          raise AddressError, 'unavailable address'
        when 'REQUEST_DENIED' then
          raise CredentialsError, 'request was denied'
        when 'OVER_QUERY_LIMIT' then
          raise CredentialsError, 'too many queries'
        else
          raise Error, "#{response.code}"
        end
      end

      # Creates a URL from the Hash +params+.
      # sets the output type to 'xml'.
      def make_url(params) #:nodoc:
        super params.merge(:sensor => false)
      end
    end
  end
end