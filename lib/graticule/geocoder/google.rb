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

      PRECISION = {
        :unknown => Precision::Unknown,      # Unknown location.
        :country => Precision::Country,      # Country level accuracy.
        :region => Precision::Region,       # Region (state, province, prefecture, etc.) level accuracy
        :locality => Precision::Locality,     # Town (city, village) level accuracy.
        :postal_code => Precision::PostalCode,   # Post code (zip code) level accuracy.
        :street_address  => Precision::Street,       # Street level accuracy.
      }

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

      class Result
        include HappyMapper
        tag 'result'
        has_many :types, Type
        element :formatted_address, String
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
        element :lat, Float
        element :lng, Float
      end

      class GeocodeResponse
        include HappyMapper
        tag 'GeocodeResponse'
        element :code, String, :tag => 'status'
        
        has_many :address_components, AddressComponent
        has_one :location, Geometry
        has_one :result, Result
       
        def get_type(type)
          address_components.detect do |component|
            component.types.detect {|item|  item.name == type } 
          end
        end

        def get_result_type
          result.types.first.name
        end

        def street
          route = get_type('route')
          route.presence ? route.short_name : ''
        end

        def locality
          locality = get_type('locality') || get_type('sublocality') || get_type('neighborhood')
          locality.presence ? locality.short_name : ''
        end

        def region
          region = get_type('administrative_area_level_1')
          region.presence ? region.short_name : ''
        end

        def postal_code
          postal_code = get_type('postal_code')
          postal_code.presence ? postal_code.short_name : ''
        end

        def country
          country = get_type('country')
          country.presence ? country.short_name : ''
        end

        def latitude
          location.lat
        end

        def longitude
          location.lng
        end

        def precision
          precision = get_result_type
          PRECISION[precision.to_sym] || PRECISION[:locality]  
        end
      end

      def prepare_response(xml)
        GeocodeResponse.parse(xml, :single => true)
      end

      def parse_response(response) #:nodoc:
        Location.new(
          :latitude    => response.latitude,
          :longitude   => response.longitude,
          :street      => response.street,
          :locality    => response.locality,
          :region      => response.region,
          :postal_code => response.postal_code,
          :country     => response.country,
          :precision   => response.precision
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