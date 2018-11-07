defmodule Explorer.Token.FunctionsReader do
  @moduledoc """
  Reads Token's fields using Smart Contract functions from the blockchain.
  """

  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Reader

  @contract_abi [
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "decimals",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint8"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "totalSupply",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint256"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    }
  ]

  @contract_functions %{
    "totalSupply" => [],
    "decimals" => [],
    "name" => [],
    "symbol" => []
  }

  @doc """
  Read functions below in the Smart Contract given the Contract's address hash.

  * totalSupply
  * decimals
  * name
  * symbol

  This function will return a map with the functions that were readed, for instance:

  * Given that all functions were readed:
  %{
    "totalSupply" => [],
    "decimals" => [],
    "name" => [],
    "symbol" => []
  }

  * Given that some of them were readed:
  %{
    "name" => [],
    "symbol" => []
  }
  """
  def get_functions_of(%Hash{byte_count: unquote(Hash.Address.byte_count())} = address) do
    address_string = Hash.to_string(address)

    get_functions_of(address_string)
  end

  def get_functions_of(contract_address_hash) do
    contract_functions_result = Reader.query_contract(contract_address_hash, @contract_abi, @contract_functions)

    format_contract_functions_result(contract_functions_result, contract_address_hash)
  end

  defp format_contract_functions_result(contract_functions, contract_address_hash) do
    contract_functions =
      for {function_name, {:ok, [function_data]}} <- contract_functions, into: %{} do
        {atomized_key(function_name), function_data}
      end

    contract_functions
    |> handle_invalid_strings(contract_address_hash)
    |> handle_large_strings
  end

  defp atomized_key("decimals"), do: :decimals
  defp atomized_key("name"), do: :name
  defp atomized_key("symbol"), do: :symbol
  defp atomized_key("totalSupply"), do: :total_supply

  # It's a temp fix to store tokens that have names and/or symbols with characters that the database
  # doesn't accept. See https://github.com/poanetwork/blockscout/issues/669 for more info.
  defp handle_invalid_strings(%{name: name, symbol: symbol} = contract_functions, contract_address_hash) do
    name = handle_invalid_name(name, contract_address_hash)
    symbol = handle_invalid_symbol(symbol)

    %{contract_functions | name: name, symbol: symbol}
  end

  defp handle_invalid_strings(%{name: name} = contract_functions, contract_address_hash) do
    name = handle_invalid_name(name, contract_address_hash)

    %{contract_functions | name: name}
  end

  defp handle_invalid_strings(%{symbol: symbol} = contract_functions, _contract_address_hash) do
    symbol = handle_invalid_symbol(symbol)

    %{contract_functions | symbol: symbol}
  end

  defp handle_invalid_strings(contract_functions, _contract_address_hash), do: contract_functions

  defp handle_invalid_name(nil, _contract_address_hash), do: nil

  defp handle_invalid_name(name, contract_address_hash) do
    case String.valid?(name) do
      true -> remove_null_bytes(name)
      false -> format_according_contract_address_hash(contract_address_hash)
    end
  end

  defp handle_invalid_symbol(symbol) do
    case String.valid?(symbol) do
      true -> remove_null_bytes(symbol)
      false -> nil
    end
  end

  defp format_according_contract_address_hash(contract_address_hash) do
    String.slice(contract_address_hash, 0, 6)
  end

  defp handle_large_strings(%{name: name, symbol: symbol} = contract_functions) do
    [name, symbol] = Enum.map([name, symbol], &handle_large_string/1)

    %{contract_functions | name: name, symbol: symbol}
  end

  defp handle_large_strings(%{name: name} = contract_functions) do
    name = handle_large_string(name)

    %{contract_functions | name: name}
  end

  defp handle_large_strings(%{symbol: symbol} = contract_functions) do
    symbol = handle_large_string(symbol)

    %{contract_functions | symbol: symbol}
  end

  defp handle_large_strings(contract_functions), do: contract_functions

  defp handle_large_string(nil), do: nil
  defp handle_large_string(string), do: handle_large_string(string, byte_size(string))
  defp handle_large_string(string, size) when size > 255, do: binary_part(string, 0, 255)
  defp handle_large_string(string, _size), do: string

  defp remove_null_bytes(string) do
    String.replace(string, "\0", "")
  end
end