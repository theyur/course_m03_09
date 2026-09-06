var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();

    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild",
    "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

var cities = new[]
{
    "Tokyo", "New York", "London", "Paris", "Berlin",
    "Madrid", "Rome", "Cairo", "Lagos", "Nairobi",
    "Mumbai", "Beijing", "Seoul", "Sydney", "Toronto",
    "Mexico City", "São Paulo", "Buenos Aires", "Dubai", "Singapore"
};

app.MapGet("/weatherforecast", () =>
    {
        var forecast = Enumerable.Range(1, 5)
            .Select(index => new WeatherForecast(
                cities[Random.Shared.Next(cities.Length)],
                DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
                Random.Shared.Next(-20, 55),
                summaries[Random.Shared.Next(summaries.Length)]))
            .ToArray();

        return forecast;
    })
    .WithName("GetWeatherForecast");

app.MapGet("/cities", () => cities)
    .WithName("GetCities");

app.Run();

record WeatherForecast(string City, DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}