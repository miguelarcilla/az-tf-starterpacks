FROM mcr.microsoft.com/dotnet/sdk:5.0-focal AS build
WORKDIR /WeatherShare

# Copy csproj and restore as distinct layers
COPY WeatherShare/*.csproj ./
RUN dotnet restore

# Copy everything else and build website
COPY WeatherShare/. ./
RUN dotnet publish -c release -o /WeatherShareApp --no-restore

# Final stage / image
FROM mcr.microsoft.com/dotnet/aspnet:5.0
WORKDIR /WeatherShareApp
COPY --from=build /WeatherShareApp ./
ENTRYPOINT ["dotnet", "WeatherShare.dll"]