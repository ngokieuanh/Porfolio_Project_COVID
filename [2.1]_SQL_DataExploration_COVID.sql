--[1] Thông tin về số ca nhiễm, số ca tử vong, dân số của mỗi quốc gia
SELECT 
	location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
FROM KIUANH_PORTFOLIO..coviddeaths
ORDER BY 1,2

-- [2] Thông tin về số ca nhiễm, số ca tử vong và tỷ lệ % tử vong trên số ca nhiễm của mỗi quốc gia theo ngày
SELECT 
	location, 
	date, 
	total_cases, 
	total_deaths, 
	(total_deaths/total_cases)*100 as DeathsPercentage
FROM KIUANH_PORTFOLIO..CovidDeaths
ORDER BY 1,2

-- [3]  Thông tin về số ca nhiễm, dân số và tỷ lệ % ca nhiễm trên dân số của mỗi quốc gia theo ngày
SELECT 
	location, 
	date, 
	total_cases,
	population,
	(total_cases/population)*100 as DeathsPercentage
FROM KIUANH_PORTFOLIO..CovidDeaths
ORDER BY 1,2

--[4] Tổng số ca nhiễm mới theo ngày 
SELECT 
	date, 
	SUM(new_cases) AS TotalNewCases
FROM KIUANH_PORTFOLIO..CovidDeaths
GROUP BY date
ORDER BY 1

-- [5] Top 10 quốc gia có số ca nhiễm cao nhất
SELECT TOP 10
	location,
	SUM(Total_deaths) as TotalDeathCount 
FROM CovidDeaths
WHERE continent is not null
GROUP BY location
ORDER BY TotalDeathCount desc
--[6] Tổng số ca tử vong của mỗi lục địa
SELECT
	continent,
	MAX(Total_deaths) as TotalDeathCount 
FROM CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY TotalDeathCount desc

-- [7] Thủ tục dùng để nhập tên quốc gia để lấy thông tin về số ca nhiễm, dân số, tỷ lệ % ca nhiễm trên dân số theo ngày
CREATE PROCEDURE GetCountryCovidStats
    @CountryName NVARCHAR(255)
AS
BEGIN
    SELECT 
        location, 
        date, 
        total_cases,
        population,
        (total_cases / population) * 100 AS DeathsPercentage
    FROM 
        KIUANH_PORTFOLIO..CovidDeaths
    WHERE 
        location = @CountryName
    ORDER BY 
        location, date;
END;
-- Sử dụng thủ tục ở mục 7
EXEC GetCountryCovidStats 'Vietnam';

-- [8] Hàm dùng để nhập tên quốc gia để lấy thông tin về số ca nhiễm, ca tử vong, tỷ lệ % ca tử vong trên ca nhiễm theo ngày
CREATE FUNCTION CalculateDeathsPercentage
(
    @CountryName NVARCHAR(255)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        location, 
        date, 
        total_cases, 
        total_deaths, 
        (total_deaths / total_cases) * 100 AS DeathsPercentage
    FROM 
        KIUANH_PORTFOLIO..CovidDeaths
    WHERE 
        location = @CountryName
);
-- Sử dụng hàm ở mục 8 sắp xếp theo location, date
SELECT * 
FROM CalculateDeathsPercentage('China')
ORDER BY location, date;

-- [9] Tính toán tỷ lệ phần trăm tử vong trên dân số của mỗi quốc gia và sắp xếp kết quả theo tỷ lệ phần trăm nhiễm
SELECT
    Location,
    Population,
    Date,
    MAX(total_cases) AS HighestInfectionCount,
    (MAX(total_cases) / Population) * 100 AS PercentPopulationInfected
FROM
    CovidDeaths
WHERE
    total_cases IS NOT NULL AND population IS NOT NULL
GROUP BY
    Location,
    Population,
    Date
ORDER BY
    PercentPopulationInfected DESC;

-- [10] Tổng số ca nhiễm mới, tổng số ca tử vong mới và tính toán tỷ lệ % số ca tử vong mới trên số ca nhiễm mới
SELECT 
    SUM(new_cases) AS TotalNewCases,
    SUM(new_deaths) AS TotalNewDeaths,
    CASE WHEN SUM(new_cases) = 0 THEN NULL ELSE (SUM(new_deaths) * 100.0 / SUM(new_cases)) END AS NewDeathPercentage
FROM 
    CovidDeaths
WHERE 
    continent IS NOT NULL;

-- [11] Tính tổng số ca tử vong COVID-19 tại mỗi lục đại và sắp xếp kết quả theo số ca tử vong giảm dần
SELECT 
	continent,
	SUM(new_deaths) AS TotalDeathCount
FROM CovidDeaths
WHERE continent is not null
	and location not in ('World', 'European Union','International')
GROUP BY continent
ORDER BY TotalDeathCount desc

-- [12] Lấy thông tin về số liệu tử vong và số liều vắc-xin mới
SELECT dea.continent, dea.location,dea.date, dea.population,
	vac.new_vaccinations
FROM CovidDeaths dea JOIN CovidVaccinations vac
	ON dea.location= vac.location
	AND dea.date= vac.date
WHERE dea.continent is not null
	AND vac.new_vaccinations is not null
ORDER BY 1,2
-- (13) Sử dụng CTE tính toán tỷ lệ % số liều vắc-xin mới trên dân số theo ngày và lục địa
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, Rolling)
AS (
  SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(float, vac.new_vaccinations)) OVER (PARTITION BY dea.continent ORDER BY dea.date) AS Rolling
  FROM
    CovidDeaths AS dea
    JOIN CovidVaccinations AS vac
      ON dea.location = vac.location
      AND dea.date = vac.date
  WHERE
    dea.continent IS NOT NULL
)
SELECT *, (Rolling/Population) *100
FROM PopvsVac;

/* 14 Sử dụng bảng tạm để lưu trữ kết quả của việc tính toán tỷ lệ phần trăm dân số đã tiêm vắc-xin dựa trên CTE
Sau đó truy vấn dữ liệu từ bảng tạm và tính toán tỷ lệ phần trăm tiêm vắc-xin trên dân số */
DROP TABLE if exists #PercentPopulationVac
Create Table #PercentPopulationVac
(
Continent nvarchar(255),
Location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
RollingPeopleVaccinated numeric
)
insert into #PercentPopulationVac
  SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(float, vac.new_vaccinations)) OVER (PARTITION BY dea.continent ORDER BY dea.date) AS RollingPeopleVaccinated
  FROM
    CovidDeaths AS dea
    JOIN CovidVaccinations AS vac
      ON dea.location = vac.location
      AND dea.date = vac.date
  WHERE
    dea.continent IS NOT NULL
SELECT *, (RollingPeopleVaccinated/Population) *100 as PercentRPC
FROM #PercentPopulationVac;

