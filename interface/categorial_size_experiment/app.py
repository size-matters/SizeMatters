from flask import Flask, render_template, request, make_response, redirect
import json
import pandas as pd
from gspread_dataframe import get_as_dataframe, set_with_dataframe
import gspread
from oauth2client.service_account import ServiceAccountCredentials

app = Flask(__name__)


scope = ['https://spreadsheets.google.com/feeds',
        'https://www.googleapis.com/auth/drive']
credentials = ServiceAccountCredentials.from_json_keyfile_name(
    'creds.json', scope
)
gc = gspread.authorize(credentials)

SPREADSHEET = gc.open('SORTING. NEW EXPERIMENT')


@app.route('/')
def main_page():
    return render_template('loading.html')


@app.route('/main')
def main():
    animals = get_as_dataframe(
        SPREADSHEET.worksheet('animals')
        ).dropna(axis=0, how='all'), 'animals'
    birds = get_as_dataframe(
        SPREADSHEET.worksheet('birds')
        ).dropna(axis=0, how='all'), 'birds'
    tools = get_as_dataframe(
        SPREADSHEET.worksheet('tools')
        ).dropna(axis=0, how='all'), 'tools'
    bodyparts = get_as_dataframe(
        SPREADSHEET.worksheet('bodyparts')
        ).dropna(axis=0, how='all'), 'bodyparts'

    sorted_by_length = sorted([animals, birds, tools, bodyparts], key=lambda x: len(x[0]))

    resp = make_response(render_template('main.html'))

    resp.set_cookie('order', ' '.join([x[1] for x in sorted_by_length]))
    resp.set_cookie('initial_order', ' '.join([x[1] for x in sorted_by_length]))

    return resp


@app.route('/animals')
def animals():
    with open('./static/data/animals.txt', encoding='utf8') as f:
        animals = f.read().splitlines()

    return render_template('index.html', data=animals, set="animals")


@app.route('/birds')
def birds():
    print(request.cookies)
    with open('./static/data/birds.txt', encoding='utf8') as f:
        birds = f.read().splitlines()

    return render_template('index.html', data=birds, set="birds")


@app.route('/tools')
def tools():
    with open('./static/data/tools.txt', encoding='utf8') as f:
        tools = f.read().splitlines()

    return render_template('index.html', data=tools, set="tools")


@app.route('/bodyparts')
def bodyparts():
    with open('./static/data/bodyparts.txt', encoding='utf8') as f:
        bodyparts = f.read().splitlines()

    return render_template('index.html', data=bodyparts, set="bodyparts")


@app.route('/results', methods = ['POST', 'GET'])
def results():
    sorting = json.loads(request.form.get('data'))
    dct_sorting = {}
    for i, group in enumerate(sorting, 1):
        for word in group:
            dct_sorting[word] = i

    print(request.cookies['end_time'], request.cookies['start_time'])

    dct_sorting.update({
        'age': request.cookies['age'],
        'gender': request.cookies['gender'],
        'order': request.cookies['initial_order'],
        'time': round((int(request.cookies['end_time']) - int(request.cookies['start_time'])) / 1000, 2)
    })

    sheetname = request.form.get('sheetname')

    worksheet = SPREADSHEET.worksheet(sheetname)

    df = get_as_dataframe(worksheet)

    df = df[df.columns.drop(list(df.filter(regex='Unnamed')))].dropna(axis=0, how='all')
    df = pd.concat([
        df,
        pd.DataFrame([dct_sorting])
        ], sort=True)
    set_with_dataframe(worksheet, df)
    print(dct_sorting)
    return ''


@app.route('/choose_set')
def choose_set():
    choose = request.cookies.get('order').split()[0].strip('"')
    return choose


@app.route('/success')
def success():
    return render_template('success.html')


@app.route('/finish')
def finish():
    return render_template('finish.html')


if __name__ == '__main__':
    app.run(debug=True)
