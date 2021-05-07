import { QueryClient, QueryClientProvider } from 'react-query';
import React from 'react';
import { createMuiTheme, ThemeProvider } from '@material-ui/core/styles';
import CssBaseline from '@material-ui/core/CssBaseline';
import blue from '@material-ui/core/colors/blue';
import amber from '@material-ui/core/colors/amber';
import styled from 'styled-components';
import Content from './Content';
import Wallet from './components/Wallet';
import Header from './Header';

const queryClient = new QueryClient();
const Wrapper = styled.div``;

const theme = createMuiTheme({
  overrides: {
    MuiCssBaseline: {
      '@global': {
        body: {},
      },
    },
  },
  palette: {
    primary: {
      main: '#0be1e1',
    },
  },
});

function App() {
  return (
    <div className='App'>
      <QueryClientProvider client={queryClient}>
        <Wallet>
          <ThemeProvider theme={theme}>
            <CssBaseline />
            <Wrapper>
              <Header />
              <Content />
            </Wrapper>
          </ThemeProvider>
        </Wallet>
        {/* <ReactQueryDevtools /> */}
      </QueryClientProvider>
    </div>
  );
}

export default App;
