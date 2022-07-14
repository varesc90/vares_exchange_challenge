defmodule MATCH do
  @moduledoc """
  Documentation for `MATCH`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> MATCH.hello()
      :world

  """
  def match_engine_from_file() do
    {_status, file_content} = File.read("input.json")
    IO.inspect(match_engine(file_content))
    {_status, content} = match_engine(file_content)
    File.write("output.json",content)
  end

  def match_engine(json_string) do


    {_status, list} = JSON.decode(json_string)
    orders = list["orders"]

    output = %{
      :buy => [],
      :sell => [],
      :orders => orders
    }

    buy =
      enhance_result(itelate_through_list_and_calculate(output)[:buy])
      |> Enum.sort(&(&1["price"] > &2["price"]))

    sell =
      enhance_result(itelate_through_list_and_calculate(output)[:sell])
      |> Enum.sort(&(&1[:price] < &2[:price]))

    JSON.encode(%{
      :buy => buy |> Enum.filter(fn y -> y[:volume] > 0 end),
      :sell => sell |> Enum.filter(fn y -> y[:volume] > 0 end)
    })
  end

  def enhance_result(list) do
    list
    |> Enum.map(fn x ->
      %{
        :price => Map.get(x, "price") || Map.get(x, :price),
        :volume => Map.get(x, "amount") || Map.get(x, :amount)
      }
    end)
    |> Enum.filter(fn y -> Map.get(y, "volume") || Map.get(y, :volume) != 0 end)
    |> Enum.group_by(fn x -> x.price end)
    |> Enum.map(fn {key, value} ->
      %{
        price: key,
        volume: value |> Enum.map(fn x -> x.volume end) |> Enum.sum() |> Float.round(3)
      }
    end)
  end

  def itelate_through_list_and_calculate(map) do
    if(length(map[:orders]) > 0) do
      cond do
        List.first(map[:orders])["command"] == "buy" ->
          matchCondition =
            map[:sell]
            |> Enum.filter(fn x -> x[:price] <= List.first(map[:orders])["price"] end)
            |> Enum.sort(&(&1["price"] < &2["price"]))

          buyTxn =
            buy_transaction(%{:order => List.first(map[:orders]), :match => matchCondition})

          itelate_through_list_and_calculate(%{
            :orders => List.delete_at(map[:orders], 0),
            :sell =>
              if(length(buyTxn[:match]) > 0,
                do:
                  [List.first(buyTxn[:match]) | map[:sell]]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end),
                else:
                  map[:sell]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end)
                  |> Enum.filter(fn x ->
                    (Map.get(x, "price") || Map.get(x, :price)) >
                      (Map.get(buyTxn[:order], "price") ||
                         Map.get(buyTxn[:order], :price))
                  end)
              ),
            :buy =>
              if(buyTxn[:order]["amount"] > 0,
                do:
                  [buyTxn[:order] | map[:buy]]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end),
                else:
                  map[:sell]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end)
              )
          })

        List.first(map[:orders])["command"] == "sell" ->
          matchCondition =
            map[:buy]
            |> Enum.filter(fn x -> x[:price] >= List.first(map[:orders])["price"] end)
            |> Enum.sort(&((&1["price"] || &1[:price]) > (&2["price"] || &2[:price])))

          sellTxn =
            sell_transaction(%{:order => List.first(map[:orders]), :match => matchCondition})

          itelate_through_list_and_calculate(%{
            :orders => List.delete_at(map[:orders], 0),
            :sell =>
              if(sellTxn[:order]["amount"] >= 0 && List.first(sellTxn[:match]) == nil,
                do:
                  [sellTxn[:order] | map[:sell]]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end),
                else:
                  map[:sell]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end)
              ),
            :buy =>
              if(length(sellTxn[:match]) > 0,
                do:
                  [List.first(sellTxn[:match]) | map[:buy]]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end)
                  |> Enum.filter(fn x ->
                    (Map.get(x, "price") || Map.get(x, :price)) <=
                      (Map.get(List.first(sellTxn[:match]), "price") ||
                         Map.get(List.first(sellTxn[:match]), :price))
                  end),
                else:
                  map[:buy]
                  |> Enum.group_by(fn x -> Map.get(x, "price") || Map.get(x, :price) end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount:
                        value
                        |> Enum.map(fn x -> Map.get(x, "amount") || Map.get(x, :amount) end)
                        |> Enum.sum()
                    }
                  end)
              )
          })

        true ->
          itelate_through_list_and_calculate(%{
            :orders => List.delete_at(map[:orders], 0),
            :sell =>
              if(List.first(map[:orders])["command"] == "sell",
                do:
                  [List.first(map[:orders]) | map[:sell]]
                  |> Enum.group_by(fn x -> x.price end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount: value |> Enum.map(fn x -> x.amount end) |> Enum.sum()
                    }
                  end),
                else:
                  map[:sell]
                  |> Enum.group_by(fn x -> x.price end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "sell",
                      amount: value |> Enum.map(fn x -> x.amount end) |> Enum.sum()
                    }
                  end)
              ),
            :buy =>
              if(List.first(map[:orders])["command"] == "buy",
                do:
                  [List.first(map[:orders]) | map[:buy]]
                  |> Enum.group_by(fn x -> x.price end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "buy",
                      amount: value |> Enum.map(fn x -> x.amount end) |> Enum.sum()
                    }
                  end),
                else:
                  map[:buy]
                  |> Enum.group_by(fn x -> x.price end)
                  |> Enum.map(fn {key, value} ->
                    %{
                      price: key,
                      command: "buy",
                      amount: value |> Enum.map(fn x -> x.amount end) |> Enum.sum()
                    }
                  end)
              )
          })
      end
    else
      %{:buy => map[:buy], :sell => map[:sell], :orders => map[:orders]}
    end
  end

  def sell_transaction(map) do
    cond do
      length(map[:match]) > 0 && map[:order]["amount"] !== 0 ->
        diff =
          Float.round(
            (map[:order]["amount"] || map[:order][:amount]) -
              (List.first(map[:match])["amount"] || List.first(map[:match])[:amount]),
            3
          )

        sell_transaction(%{
          :order =>
            if(diff <= 0,
              do: map[:order] |> Map.replace("amount", 0),
              else: map[:order] |> Map.replace("amount", diff)
            ),
          :match =>
            if(diff >= 0,
              do: List.delete_at(map[:match], 0),
              else: [
                List.first(map[:match])
                |> Map.replace(:amount, Float.round(0 - map[:order]["amount"], 3))
                | List.delete_at(map[:match], 0)
              ]
            )
        })

      true ->
        map
    end
  end

  def buy_transaction(map) do
    cond do
      length(map[:match]) > 0 && map[:order]["amount"] !== 0 ->
        diff =
          Float.round(
            map[:order]["amount"] -
              (List.first(map[:match])["amount"] || List.first(map[:match])[:amount]),
            3
          )

        buy_transaction(%{
          :order =>
            if(diff <= 0,
              do: map[:order] |> Map.replace("amount", 0),
              else:
                map[:order]
                |> Map.replace(
                  "amount",
                  map[:order]["amount"] -
                    (List.first(map[:match])["amount"] || List.first(map[:match])[:amount])
                )
            ),
          :match =>
            if(diff >= 0,
              do: List.delete_at(map[:match], 0),
              else: [
                List.first(map[:match])
                |> Map.replace("amount", Float.round(0 - map[:order]["amount"], 3))
                | List.delete_at(map[:match], 0)
              ]
            )
        })

      true ->
        map
    end
  end
end

MATCH.match_engine_from_file()
