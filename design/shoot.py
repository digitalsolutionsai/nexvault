import asyncio, sys, pathlib
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={"width":1400,"height":1900}, device_scale_factor=2)
        await pg.goto(pathlib.Path("mockups.html").resolve().as_uri()); await pg.wait_for_timeout(1500)
        for i in range(1,7):
            await pg.locator(f"#s{i}").screenshot(path=f"shots/s{i}.png")
        await b.close()
asyncio.run(main())
