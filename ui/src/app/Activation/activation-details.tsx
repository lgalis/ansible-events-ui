import {CardBody, PageSection, Title} from '@patternfly/react-core';
import { Link, useParams } from 'react-router-dom';
import React, { useState, useEffect } from 'react';
import Ansi from "ansi-to-react";
import {
  Card,
  CardTitle,
  SimpleListItem,
  Stack,
  StackItem,
} from '@patternfly/react-core';
import {getServer} from '@app/utils/utils';
import {SimpleList} from "@patternfly/react-core/dist/js";

const client = new WebSocket('ws://' + getServer() + '/api/ws');

client.onopen = () => {
    console.log('Websocket client connected');
};

const endpoint1 = 'http://' + getServer() + '/api/activation_instance/';

const ActivationDetails: React.FunctionComponent = () => {

  const [activation, setActivation] = useState([]);

  const { id } = useParams();
  console.log(id);


  useEffect(() => {
     fetch(endpoint1 + id, {
       headers: {
         'Content-Type': 'application/json',
       },
     }).then(response => response.json())
    .then(data => setActivation(data));
  }, []);

  const [stdout, setStdout] = useState([]);
  const [newStdout, setNewStdout] = useState('');

  const [websocket_client, setWebsocketClient] = useState([]);
  useEffect(() => {
    const wc = new WebSocket('ws://' + getServer() + '/api/ws');
    setWebsocketClient(wc);
    wc.onopen = () => {
        console.log('Websocket client connected');
    };
    wc.onmessage = (message) => {
        console.log('update: ' + message.data);
        const [messageType, data] = JSON.parse(message.data);
        if (messageType === 'Stdout') {
          const { stdout: dataStdout } = data;
          setNewStdout(dataStdout);
        }
    }
  }, []);

  useEffect(() => {
    console.log(["newStdout: ",  newStdout]);
    console.log(["stdout: ",  stdout]);
    setStdout([...stdout, newStdout]);
  }, [newStdout]);

  const [jobs, setJobs] = useState([]);
  const [newJob, setNewJob] = useState([]);

  const [update_client, setUpdateClient] = useState([]);
  useEffect(() => {
    const uc = new WebSocket('ws://' + getServer() + '/api/ws-activation/' + id);
    setUpdateClient(uc);
    uc.onopen = () => {
        console.log('Update client connected');
    };
  }, []);

  return (
  <React.Fragment>
    <Link to={"/rulesetfile/" + activation.ruleset_id}>{activation.ruleset_name}</Link>
    <Link to={"/inventory/" + activation.inventory_id}>{activation.inventory_name}</Link>
    <Link to={"/var/" + activation.extra_var_id}>{activation.extra_vars_name}</Link>
    <Stack>
      <StackItem>
        <Card>
          <CardTitle>Standard Out</CardTitle>
          <CardBody>
            {stdout.length !== 0 && (
              <SimpleList style={{ whiteSpace: 'pre-wrap' }}>
                {stdout.map((item, i) => (
                  <SimpleListItem key={i}><Ansi>{item}</Ansi></SimpleListItem>
                ))}
              </SimpleList>
            )}
          </CardBody>
        </Card>
      </StackItem>
    </Stack>
  </React.Fragment>
)
}

export { ActivationDetails };